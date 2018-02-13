defmodule Daisy.Random do
  @moduledoc """
  Simple module to keep our randoms looking random, but in truth, fully
  deterministic.
  """

  def init(seed) do
    {0, seed}
  end

  def random_el(rand, list) do
    list_length = list |> Enum.count

    el =
      rand
      |> generate()
      |> sha256_int
      |> rem(list_length)

    {next(rand), Enum.at(list, el)}
  end

  def unique_id(rand) do
    <<bytes::binary-size(20), _rest::binary>> =
      rand
      |> generate()
      |> sha256

    {next(rand), bytes |> Base.encode16(case: :lower)}
  end

  defp sha256(int) do
    int
    |> :binary.encode_unsigned()
    |> do_sha256
  end

  defp sha256_int(int) do
    int
    |> :binary.encode_unsigned()
    |> do_sha256
    |> :binary.decode_unsigned()
  end

  defp do_sha256(bin) do
    :crypto.hash(:sha256, bin)
  end

  defp generate({acc, seed}) do
    acc * 1_000_000_000_000_000_000 + seed
  end

  defp next({acc, seed}) do
    {acc + 1, seed}
  end

end