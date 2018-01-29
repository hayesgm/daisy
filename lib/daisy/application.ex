defmodule Daisy.Application do
  use Application

  def start(_type, _args) do
    runner = Daisy.get_runner()
    reader = Daisy.get_reader()

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Daisy.API.Router, [], [port: 2235]),
      Supervisor.Spec.worker(Daisy.Storage, [[name: Daisy.Storage]]),
      Supervisor.Spec.worker(Daisy.Persistence, [[name: Daisy.Persistence]]),
      Supervisor.Spec.worker(Daisy.Minter, [Daisy.Storage, :resolve, runner, reader, [mine: true, name: Daisy.Minter]]),
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end