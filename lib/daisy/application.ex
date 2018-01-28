defmodule Daisy.Application do
  use Application

  def start(_type, _args) do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Daisy.API.Router, [], [port: 2235]),
      Supervisor.Spec.worker(Daisy.Storage, [[name: Daisy.Storage]])
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end