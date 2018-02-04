defmodule Daisy do
  @moduledoc """
  Documentation for Daisy.
  """

  def get_runner(), do: Application.get_env(:daisy, :runner)
  def get_reader(), do: Application.get_env(:daisy, :reader)
  def get_ipfs_key(), do: Application.get_env(:daisy, :ipfs_key)

end
