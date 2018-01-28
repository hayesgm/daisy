defmodule Daisy.Encoder do
  @moduledoc """
  Simple module around encoding and decoding base58. This currently
  is just a stub ti Base58Check so that we can swap that module in the future
  if need be. Specifically, I would prefer the library we use does not decode
  the binary, since we lose padding data.
  """

  @spec encode_58(binary()) :: String.t
  def encode_58(data) do
    Base58Check.encode58(data)
  end

  @spec decode_58!(String.t) :: binary()
  def decode_58!(enc) do
    Base58Check.decode58(enc) |> :binary.encode_unsigned()
  end

  @spec maybe_decode_58!(String.t) :: binary() | nil
  def maybe_decode_58!(nil), do: nil
  def maybe_decode_58!(enc), do: decode_58!(enc)
end