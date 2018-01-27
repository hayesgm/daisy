defmodule Daisy.Prover do
  @moduledoc """
  To interact with Blockchains, etc, we'll need to provide merkle-proofs
  proving the existence of data in IPFS. This module provides a quick way
  for us to verify these proofs without any external dependencies.

  Note: we currently assume that nodes are stored as proto files. This
        may change as IPLD becomes further adopted.

  We are currently assuming nodes in the IPFS tree look at follows:

  ```proto
  message MerkleLink {
    bytes hash = 1;   // multihash of the target object
    string name = 2;  // utf string name
    uint64 tsize = 3; // cumulative size of target object
  }

  // An IPFS MerkleDAG Node
  message MerkleNode {
    repeated MerkleLink links = 2; // refs to other objects
    bytes data = 1; // opaque user data
  }
  ```

  Proof takes the form of the protobuf-encoded version of each MerkleNode,
  starting at the leaf node.

  The algorithm starts at the leaf node and verifies that the `MerkleNode.data`
  of that protobuf matches the expected data. From there, we begin to verify each
  `MerkleLink` up the tree, starting with the sha256 hash of the first `MerkleNode`
  for that leaf node.

  For each link, we take the hash of the previously verified `MerkleNode` and we
  look for that value in the `links` of the higher-up `MerkleNode`. We need to match
  both the `link.hash` and `link.name` (which comes from the path). If so, we continue
  up until we've verified the path to the root.

  TODO: We currently assume all nodes will be encoded in sha256.
  TODO: We do not currently support newer changes with IPLD.
  """
  use Bitwise

  require Logger

  @spec verify_proof!(Storage.root_hash, String.t, String.t, [binary()]) :: :qed | :invalid_data_proof | {:invalid_link_proof, [String.t], [binary()], String.t}
  def verify_proof!(root_hash, full_path, value, [data_proto|link_protos]=proof) do
    # We need to walk back the proof verifying each step
    Logger.debug("[Prover] Attempting to verify proof, \n\troot_hash=#{inspect_hash root_hash}\n\tpath=#{full_path}\n\tproof=\n#{(for proto <- proof, do: "\t\t" <> inspect_proto proto) |> Enum.join("\n")}")

    reversed_path = full_path |> Path.split |> Enum.reverse

    if !proof_match_data(data_proto, value) do
      Logger.debug("[Prover] Data proto failed to match data, `#{value}` versus `#{inspect_proto data_proto}`")
      :invalid_data_proof
    else
      Logger.debug("[Prover] Data proto matched data. Attempting to match links.")

      # We're going to do this iteratively, since it'll be closer to our
      # on-chain check
      result = Enum.reduce(Enum.zip(reversed_path, link_protos), {:ok, data_proto}, fn
        {path, link_proto}, {:ok, value} ->
          # First, hash the current document
          value_hashed = :crypto.hash(:sha256, value)

          # Next, look in the proof for that value
          # Iterate through the elements of the protobuf until we
          # find a link with our path and hash, otherwise fail

          if proof_match_link(link_proto, path, value_hashed) do
            Logger.debug("[Prover] Matched link proof for #{path} with hash #{inspect_hash value_hashed} via proto #{inspect_proto link_proto}.")

            # Finally, continue on with proof as next value
            {:ok, link_proto}
          else
            Logger.debug("[Prover] Failed to match link proof for #{path} with hash #{inspect_hash value_hashed} via proto #{inspect_proto link_proto}.")

            {:invalid_proof, path}
          end
        _, els -> els
      end)

      case result do
        {:ok, _} ->
          Logger.debug("[Prover] Matched all proofs, q.e.d.")

          :qed
        els -> els
      end
    end
  end

  defp proof_match_data(proto, data) do
    fields = decode_protobuf(proto)

    # Only inspect data
    for {1, field_val} <- fields do
      field_val == data
    end |> Enum.member?(true)
  end

  defp proof_match_link(proto, path, value_hashed) do
    fields = decode_protobuf(proto)

    # Only inspect links
    for {2, field_val} <- fields do
      link_fields = decode_protobuf(field_val) |> Enum.into(%{})

      # TODO: This assume that we're only doing sha256
      multihashed_value = <<18, 32>> <> value_hashed

      # Let's see if this link matches (making some assumptions about multi-hash)
      link_fields[2] == path
        && link_fields[1] == multihashed_value
    end |> Enum.member?(true)
  end

  def decode_protobuf(proto) do
    do_decode_protobuf(proto, [])
  end

  defp do_decode_protobuf(<<>>, fields), do: fields
  defp do_decode_protobuf(proto, fields) do
    {info, rest} = decode_varint(proto)

    wire_type = info &&& 0b111
    field_number = info >>> 3

    {field_data, rest_2} = case wire_type do
      0 ->
        decode_varint(rest)
      2 ->
        {field_length, field_rest} = decode_varint(rest)
        <<field_data::binary-size(field_length), rest_2::binary>> = field_rest

        {field_data, rest_2}
      _ -> raise "Unsupported wire type: #{wire_type}"
    end

    do_decode_protobuf(rest_2, [{field_number, field_data}|fields])
  end

  defp inspect_hash(hash), do: hash |> inspect(limit: 30)
  defp inspect_proto(proto), do: decode_protobuf(proto) |> inspect(limit: 30)

  @spec decode_varint(binary()) :: {integer(), binary()}
  def decode_varint(bin) do
    do_decode_varint(bin, 0)
  end

  @spec do_decode_varint(binary(), integer()) :: {integer(), binary()}
  def do_decode_varint(bin, curr) do
    <<continue::size(1), data::size(7), rest::binary()>> = bin

    if continue == 1 do
      do_decode_varint(rest, curr + (data <<< 7))
    else
      {curr + data, rest}
    end
  end
end