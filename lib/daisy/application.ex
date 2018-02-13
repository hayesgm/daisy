defmodule Daisy.Application do
  use Application
  require Logger

  def start(_type, _args) do
    runner = Daisy.Config.get_runner()
    reader = Daisy.Config.get_reader()
    ipfs_key = Daisy.Config.get_ipfs_key()
    initial_block_reference = Daisy.Config.initial_block_reference()

    # TODO: Check that IPFS is up and available, when?

    # Start Storage, Persistence and a Tracker
    children = [
      Supervisor.Spec.worker(Daisy.Storage, [[name: Daisy.Storage]]),
      Supervisor.Spec.worker(Daisy.Persistence, [[key_name: ipfs_key, name: Daisy.Persistence]])
    ]

    # If running API, start API server
    children = if Daisy.Config.run_api?() do
      port = Daisy.Config.get_port()
      scheme = Daisy.Config.get_scheme()

      Logger.info("Running API server at #{scheme}://localhost:#{port}/")

      [
        Plug.Adapters.Cowboy.child_spec(scheme, Daisy.API.Router, [], [port: port])
        | children
      ]
    else
      children
    end

    # If running miner, start publisher
    children = children ++ cond do
      Daisy.Config.run_leader?() ->
        [
          Supervisor.Spec.worker(Daisy.Tracker, [Daisy.Storage, initial_block_reference, :leader, runner, reader, [name: Daisy.Tracker]]),
          Supervisor.Spec.worker(Daisy.Tracker.Leader, [Daisy.Tracker, [name: Daisy.Tracker.Leader]])
        ]
      Daisy.Config.run_follower?() ->
        [
          Supervisor.Spec.worker(Daisy.Tracker, [Daisy.Storage, initial_block_reference, :follower, runner, reader, [name: Daisy.Tracker]]),
          Supervisor.Spec.worker(Daisy.Tracker.Follower, [Daisy.Tracker, Daisy.Storage, [name: Daisy.Tracker.Follower]])
        ]
      true ->
        []
    end

    Supervisor.start_link(children, strategy: :one_for_one)
  end

end