defmodule Daisy.Persistence do
  @moduledoc """
  The persistence library is used to track blocks over time. This is kept
  separate from `Daisy.Storage` because it is long-term mutable storage.
  Additionally, the actions here are much (much) slower.

  TODO: We should have the ability to store different objects at different
        keys.
  """
  use GenServer
  require Logger

  @type root_hash :: String.t
  @type data_hash :: String.t
  @type key :: String.t

  @timeout 120_000

  def start_link(opts \\ []) do
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, "5001")
    name = Keyword.get(opts, :name, nil)
    key_name = Keyword.get(opts, :key_name, nil)
    key_id = Keyword.get(opts, :key_id, nil)

    gen_server_args = if name do
      [name: name]
    else
      []
    end

    GenServer.start_link(__MODULE__, {key_name, key_id, host, port}, gen_server_args)
  end

  def init({key_name, key_id, host, port}) do
    client = IPFS.Client.new(host, port)

    {:ok, key} = get_key(client, key_name, key_id)

    Logger.debug("[#{__MODULE__} Persistence using IPFS key `#{key.name}` (#{key.id})")

    {:ok, %{
      client: client,
      key: key.id
    }}
  end

  def handle_call({:publish, root_hash}, _from, %{client: client, key: key}=state) do
    result = ipns_publish(client, root_hash, key)

    {:reply, result, state}
  end

  def handle_cast({:publish, root_hash}, %{client: client, key: key}=state) do
    {:ok, _name, _value} = ipns_publish(client, root_hash, key)

    {:noreply, state}
  end

  def handle_call(:resolve, _from, %{client: client, key: key}=state) do
    result = case ipns_resolve(client, key) do
      {:ok, "/ipfs/" <> result} -> {:ok, result}
      {:ok, invalid_result} -> {:error, "Invalid resolve result: `#{invalid_result}`"}
      error={:error, %HTTPoison.Response{body: body}} ->
        # Handle error case if not found specially
        if String.contains?(body, "\"Code\":0") do
          :not_found
        else
          error
        end
    end

    {:reply, result, state}
  end

  @spec ipns_publish(IPFS.Client.t, root_hash, key) :: {:ok, String.t, String.t} | {:error, any()}
  defp ipns_publish(client, root_hash, key) do
    with {:ok, published} <- IPFS.Client.name_publish(client, root_hash, key: key) do
      {:ok, published.name, published.value}
    end
  end

  # TODO: Handle "not found" case
  @spec ipns_resolve(IPFS.Client.t, key) :: {:ok, root_hash} | {:error, any()}
  defp ipns_resolve(client, key) do
    with {:ok, published} <- IPFS.Client.name_resolve(client, key, nocache: true) do
      {:ok, published.value}
    end
  end

  @spec get_key(IPFS.Client.t, String.t | nil, String.t | nil) :: {:ok, IPFS.Client.Key.t} | {:error, any()}
  defp get_key(client, nil, nil), do: IPFS.Client.key_gen(client, UUID.uuid4())
  defp get_key(client, key_name, nil) do
    {:ok, keys} = IPFS.Client.key_list(client)

    key = Enum.find(keys, fn key -> key.name == key_name end)

    if key do
      {:ok, key}
    else
      {:error, "cannot find key #{key_name}"}
    end
  end
  defp get_key(_client, key_name, key_id), do: {:ok, %IPFS.Client.Key{name: key_name || "", id: key_id}}

  @spec publish(identifier(), root_hash) :: :ok | {:error, any()}
  def publish(server, root_hash) do
    GenServer.call(server, {:publish, root_hash}, @timeout)
  end

  @spec publish_async(identifier(), root_hash) :: :ok | {:error, any()}
  def publish_async(server, root_hash) do
    GenServer.cast(server, {:publish, root_hash})
  end

  @spec resolve(identifier()) :: {:ok, root_hash} | :not_found | {:error, any()}
  def resolve(server) do
    GenServer.call(server, :resolve, @timeout)
  end

end