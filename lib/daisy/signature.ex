defmodule Daisy.Signature do
  @moduledoc """
  Functions for generating or verifying ECDSA digital signatures.
  """

  @type public_key :: binary()
  @type private_key :: binary()
  @type keypair :: {public_key, private_key}

  @algorithm :ecdsa
  @digest :sha256
  @key_type :ecdh
  @ec_curve :secp256k1

  @doc """
  Verifies the signature of a set of bytes.

  # TODO: Test
  """
  @spec verify_signature(binary(), Daisy.Data.Signature.t) :: {:ok, binary()} | {:error, :invalid_signature}
  def verify_signature(raw_data, signature) do
    if :crypto.verify(@algorithm, @digest, raw_data, signature.signature, [signature.public_key, @ec_curve]) do
      {:ok, signature.public_key}
    else
      {:error, :invalid_signature}
    end
  end

  @spec sign(binary(), keypair) :: Daisy.Data.Signature.t
  def sign(raw_data, {public_key, private_key}) do
    signature = :crypto.sign(@algorithm, @digest, raw_data, [private_key, @ec_curve])

    Daisy.Data.Signature.new(
      signature: signature,
      public_key: public_key
    )
  end

  @spec new_keypair() :: keypair
  def new_keypair() do
    :crypto.generate_key(@key_type, @ec_curve)
  end

end