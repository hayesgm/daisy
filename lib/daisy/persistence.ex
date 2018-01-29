defmodule Daisy.Persistence do
  @moduledoc """
  The persistence library is used to track blocks over time. This is kept
  separate from `Daisy.Storage` because it is long-term mutable storage.
  Additionally, the actions here are much (much) slower.

  TODO: We should have the ability to store different objects at different
        keys.
  """
  use GenServer

  @type root_hash :: String.t
  @type data_hash :: String.t

  @timeout 60_000

  def start_link(opts \\ []) do
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, "5001")
    name = Keyword.get(opts, :name, nil)

    gen_server_args = if name do
      [name: name]
    else
      []
    end

    GenServer.start_link(__MODULE__, {host, port}, gen_server_args)
  end

  def init({host, port}) do
    client = IPFS.Client.new(host, port)

    {:ok, %{
      client: client
    }}
  end

  def handle_call({:publish, root_hash}, _from, %{client: client}=state) do
    result = ipns_publish(client, root_hash)

    {:reply, result, state}
  end

  def handle_call(:resolve, _from, %{client: client}=state) do
    result = ipns_resolve(client)

    {:reply, result, state}
  end

  @spec ipns_publish(IPFS.Client.t, root_hash) :: {:ok, String.t, String.t} | {:error, any()}
  defp ipns_publish(client, root_hash) do
    with {:ok, published} <- IPFS.Client.name_publish(client, root_hash) do
      {:ok, published.name, published.value}
    end
  end

  @spec ipns_resolve(IPFS.Client.t) :: {:ok, root_hash} | {:error, any()}
  defp ipns_resolve(client) do
    with {:ok, published} <- IPFS.Client.name_resolve(client) do
      {:ok, published.value}
    end
  end

  @spec publish(identifier(), root_hash) :: :ok | {:error, any()}
  def publish(server, root_hash) do
    GenServer.call(server, {:publish, root_hash}, @timeout)
  end

  @spec resolve(identifier()) :: {:ok, root_hash} | {:error, any()}
  def resolve(server) do
    GenServer.call(server, :resolve)
  end

end