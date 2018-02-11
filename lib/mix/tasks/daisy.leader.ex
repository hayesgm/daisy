defmodule Mix.Tasks.Daisy.Leader do
  use Mix.Task

  @shortdoc "Starts Daisy as a leader"

  @moduledoc """
  Starts Daisy.

  ## Command line options

  The `--no-halt` flag is automatically added.
  """

  @doc false
  def run(args) do
    {parsed, args, _invalid} = OptionParser.parse(args, switches: [api: :boolean, port: :integer])
    run_api = Keyword.get(parsed, :api, false)
    api_port = Keyword.get(parsed, :port, nil)

    Application.put_env(:daisy, :api, run_api, persistent: true)
    Application.put_env(:daisy, :run_leader, true, persistent: true)

    if run_api && api_port do
      Application.put_env(:daisy, :api_port, api_port, persistent: true)
    end

    Mix.Tasks.Run.run run_args() ++ args
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?
  end

end
