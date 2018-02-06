defmodule Daisy.Application do
  use Application

  def start(_type, _args) do
    runner = Daisy.Config.get_runner()
    reader = Daisy.Config.get_reader()
    ipfs_key = Daisy.Config.get_ipfs_key()

    # TODO: Check that IPFS is up and available, when?

    # Start Storage, Persistence and our Minter
    children = [
      Supervisor.Spec.worker(Daisy.Storage, [[name: Daisy.Storage]]),
      Supervisor.Spec.worker(Daisy.Persistence, [[key_name: ipfs_key, name: Daisy.Persistence]]),
      Supervisor.Spec.worker(Daisy.Minter, [Daisy.Storage, :resolve, runner, reader, [name: Daisy.Minter]]),
    ]

    # If running API, start API server
    children = if Daisy.Config.run_api?() do
      port = Daisy.Config.get_port()
      scheme = Daisy.Config.get_scheme()

      [
        Plug.Adapters.Cowboy.child_spec(:http, Daisy.API.Router, [], [port: port])
        | children
      ]
    else
      children
    end

    # If running miner, start publisher
    children = if Daisy.Config.run_miner?() do
      [
        Supervisor.Spec.worker(Daisy.Publisher, [Daisy.Minter, [name: Daisy.Publisher]])
        | children
      ]
    else
      children
    end

    Supervisor.start_link(children, strategy: :one_for_one)
  end

end