defmodule Daisy.Storage do
  @moduledoc """
  A GenServer implemeting block storage backed by ipfs. The goal of this
  storage module is to expose functions like `get`, `put` and `update`,
  where we are always given an immutable root-hash and we return an updated
  immutable root hash. Thus, we can always walk in time, and due to the
  nature of `ipfs`, anyone can, even without having run the transactions.
  """
  use GenServer
  import Daisy.IPFS

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

  ### Server

  def handle_call(:new, _from, %{client: client}=state) do
    result = ipfs_new(client)

    {:reply, result, state}
  end

  def handle_call({:put, root_hash, path, data}, _from, %{client: client}=state) do
    put_result = ipfs_put(client, root_hash, path, data)

    {:reply, put_result, state}
  end

  def handle_call({:put_all, root_hash, values}, _from, %{client: client}=state) do
    put_all_result = ipfs_put_all(client, root_hash, values)

    {:reply, put_all_result, state}
  end

  def handle_call({:get_all, root_hash, path}, _from, %{client: client}=state) do
    # First, we'll walk down to path
    get_all_result = with {:ok, data_hash} <- ipfs_get_hash(client, root_hash, path) do
      # Then get all from there
      ipfs_get_all(client, data_hash)
    end

    {:reply, get_all_result, state}
  end

  def handle_call({:get_hash, root_hash, path}, _from, %{client: client}=state) do
    # First, we'll walk down to path
    get_hash_result = ipfs_get_hash(client, root_hash, path)

    {:reply, get_hash_result, state}
  end

  def handle_call({:put_new, root_hash, path, data}, _from, %{client: client}=state) do
    # Note: This might be slow since we need to walk entire path to find file
    result = case walk_path(client, path, root_hash) do
      {:ok, [], _found_path, _found_objects, _found_links, _data_hash} ->
        :file_exists
      {:ok, _looking_path, _found_path, _found_objects, _found_links, _sub_root_hash} ->
        with {:ok, %IPFS.Client.PatchObject{hash: data_hash}} <- IPFS.Client.object_put(client, data, false) do
          # TODO: It would be nice to put the object at `sub_root_hash` and `_looking_path`, but we need to follow the links up to root
          #       which would require more HTTP calls.
          with {:ok, %IPFS.Client.PatchObject{hash: new_root_hash}} <- IPFS.Client.object_patch_add_link(client, root_hash, path, data_hash, true) do
            {:ok, new_root_hash}
          end
        end
      els -> els
    end

    {:reply, result, state}
  end

  def handle_call({:get, root_hash, path}, _from, %{client: client}=state) do
    get_result = ipfs_get(client, root_hash, path)

    {:reply, get_result, state}
  end

  def handle_call({:ls, root_hash, path}, _from, %{client: client}=state) do
    ls_result = with :not_found <- ipfs_get_links(client, root_hash, path) do
      {:ok, []}
    end

    {:reply, ls_result, state}
  end

  def handle_call({:update, root_hash, path, update_fn, default, run_update_fn_on_default}, _from, %{client: client}=state) do
    update_result = case ipfs_get(client, root_hash, path) do
      {:ok, data} ->
        new_data = update_fn.(data)

        ipfs_put(client, root_hash, path, new_data)
      :not_found ->
        # TODO: test
        value = if run_update_fn_on_default do
          update_fn.(default)
        else
          default
        end

        ipfs_put(client, root_hash, path, value)
      els -> els
    end

    {:reply, update_result, state}
  end

  def handle_call({:save, data}, _from, %{client: client}=state) do
    save_result = ipfs_save(client, data)

    {:reply, save_result, state}
  end

  def handle_call({:retrieve, data_hash}, _from, %{client: client}=state) do
    retrieve_result = ipfs_retrieve(client, data_hash)

    {:reply, retrieve_result, state}
  end

  def handle_call({:proof, root_hash, path}, _from, %{client: client}=state) do
    # We will walk the path to the root, grabbing the full data of each node on the way
    result = case walk_path(client, path, root_hash) do
      {:ok, [], _found_path, _found_objects, found_links, data_hash} ->

        # We found a good path, let's now pull the protobuf version of each
        # object we found along the way (that's our proof!)
        protobuf_result = Enum.reduce([data_hash|found_links], {:ok, []}, fn
          link, {:ok, protobufs} ->
            with {:ok, protobuf} <- ipfs_retrieve_proto(client, link) do
              {:ok, [protobuf|protobufs]}
            end
          _, {:error, error} ->
            {:error, error}
        end)

        # TODO: We can verify data matches our expected data, if we want.
        #       Otherwise, you might return proof that proves you wrong!

        # Return the proof (protobufs) in reverse order
        with {:ok, protobufs} <- protobuf_result do
          {:ok, protobufs |> Enum.reverse}
        end

      # We didn't find the node we're looking for
      {:ok, _looking_path, _found_path, _found_objects, _found_links, _data_hash} ->
        :not_found

      # We encountered an error
      els -> els
    end

    {:reply, result, state}
  end

  ### Client

  @spec new(identifier()) :: {:ok, Daisy.IPFS.root_hash} | {:error, any()}
  def new(server) do
    GenServer.call(server, :new)
  end

  @spec get(identifier(), Daisy.IPFS.root_hash, String.t) :: {:ok, String.t} | :not_found | {:error, any()}
  def get(server, root_hash, path) do
    GenServer.call(server, {:get, root_hash, clean(path)})
  end

  @spec get_all(identifier(), Daisy.IPFS.root_hash, String.t) :: {:ok, %{}} | {:error, any()}
  def get_all(server, root_hash, path \\ "") do
    GenServer.call(server, {:get_all, root_hash, clean(path)})
  end

  @spec get_hash(identifier(), Daisy.IPFS.root_hash, String.t) :: {:ok, String.t} | :not_found | {:error, any()}
  def get_hash(server, root_hash, path) do
    GenServer.call(server, {:get_hash, root_hash, clean(path)})
  end

  @spec proof(identifier(), Daisy.IPFS.root_hash, String.t) :: :ok | :not_found | {:error, any()}
  def proof(server, root_hash, path) do
    GenServer.call(server, {:proof, root_hash, clean(path)})
  end

  @spec put(identifier(), Daisy.IPFS.root_hash, String.t, binary()) :: {:ok, Daisy.IPFS.root_hash} | {:error, any()}
  def put(server, root_hash, path, value) do
    GenServer.call(server, {:put, root_hash, clean(path), value})
  end

  @spec put_all(identifier(), Daisy.IPFS.root_hash, [{String.t, binary()}]) :: {:ok, Daisy.IPFS.root_hash} | {:error, any()}
  def put_all(server, root_hash, values) do
    GenServer.call(server, {:put_all, root_hash, values})
  end

  @spec put(identifier(), Daisy.IPFS.root_hash, String.t, binary()) :: {:ok, Daisy.IPFS.root_hash} | :file_exists | {:error, any()}
  def put_new(server, root_hash, path, value) do
    GenServer.call(server, {:put_new, root_hash, clean(path), value})
  end

  @spec update(identifier(), Daisy.IPFS.root_hash, String.t, (String.t -> String.t), [default: String.t, run_update_fn_on_default: boolean()]) :: {:ok, Daisy.IPFS.root_hash} | {:error, any()}
  def update(server, root_hash, path, update_fn, opts \\ []) do
    default = Keyword.get(opts, :default, "")
    run_update_fn_on_default = Keyword.get(opts, :run_update_fn_on_default, false)

    GenServer.call(server, {:update, root_hash, clean(path), update_fn, default, run_update_fn_on_default})
  end

  @spec ls(identifier(), Daisy.IPFS.root_hash, String.t) :: {:ok, [{String.t, Daisy.IPFS.data_hash}]} | {:error, any()}
  def ls(server, root_hash, path) do
    GenServer.call(server, {:ls, root_hash, clean(path)})
  end

  # TODO: Test
  @spec save(identifier(), binary()) :: {:ok, Daisy.IPFS.data_hash} | {:error, any()}
  def save(server, data) do
    GenServer.call(server, {:save, data})
  end

  # TODO: Test
  @spec retrieve(identifier(), Daisy.IPFS.data_hash) :: {:ok, binary()} | {:error, any()}
  def retrieve(server, data_hash) do
    GenServer.call(server, {:retrieve, data_hash})
  end

  @spec clean(String.t) :: String.t
  defp clean("/" <> path), do: path
  defp clean(path), do: path

end