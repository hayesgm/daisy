defmodule Daisy.Reader do
  @moduledoc """
  `Daisy.Runner` provides a behaviour for implementing the read-only portion
  of a Daisy VM.
  """

  @type reader :: module()

  @callback read(String.t, [String.t], identifier(), Daisy.Storage.root_hash) :: {:ok, any()} | {:erorr, any()}

  @doc """
  Reads from a given reader, which is a module which will be invoked to read
  data from the IPFS chain (without making any modifications).

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> Daisy.Reader.read(storage_pid, "", "simple", [6], Daisy.Examples.Test.Reader)
      {:ok, 11}
  """
  @spec read(identifier(), Daisy.Storage.root_hash, String.t, [String.t], reader) :: {:ok, any()} | {:error, any()}
  def read(storage_pid, final_storage, function, args, reader) do
    reader.read(function, args, storage_pid, final_storage)
  end

end