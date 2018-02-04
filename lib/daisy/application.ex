defmodule Daisy.Application do
  use Application

  def start(_type, _args) do
    runner = Daisy.get_runner()
    reader = Daisy.get_reader()
    ipfs_key = Daisy.get_ipfs_key()

    # Next, we'll stat persistence based on the key name in config

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Daisy.API.Router, [], [port: 2235]),
      Supervisor.Spec.worker(Daisy.Storage, [[name: Daisy.Storage]])
    ] ++ (if Mix.env == :test do
      []
    else
      [
        Supervisor.Spec.worker(Daisy.Persistence, [[key_name: ipfs_key, name: Daisy.Persistence]]),
        Supervisor.Spec.worker(Daisy.Minter, [Daisy.Storage, :resolve, runner, reader, [name: Daisy.Minter]]),
        Supervisor.Spec.worker(Daisy.Publisher, [Daisy.Minter, [name: Daisy.Publisher]]),
      ]
    end)

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end