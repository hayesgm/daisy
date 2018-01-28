defmodule Daisy.Reader do
  @moduledoc """
  `Daisy.Runner` provides a behaviour for implementing the read-only portion
  of a Daisy VM.
  """

  @type reader :: module()

  @callback read(identifier(), String.t, String.t, [String.t]) :: {:ok, any()} | {:erorr, any()}

  @spec read(Daisy.Block.t, identifier(), String.t, [String.t], reader) :: {:ok, any()} | {:error, any()}
  def read(block, storage_pid, function, args, reader) do
    reader.read(storage_pid, block.final_storage, function, args)
  end

end