defmodule Mix.Tasks.Daisy.Miner do
  use Mix.Task

  @shortdoc "Starts Daisy as a Miner"

  @moduledoc """
  Starts Daisy.

  ## Command line options

  The `--no-halt` flag is automatically added.
  """

  @doc false
  def run(args) do
    Application.put_env(:daisy, :run_api, true, persistent: true)
    Application.put_env(:daisy, :run_miner, true, persistent: true)
    Mix.Tasks.Run.run run_args() ++ args
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?
  end
end
