defmodule Daisy.Storage do
  @moduledoc """
  A GenServer implemeting block storage backed by ipfs. The goal of this
  storage module is to expose functions like `get`, `put` and `update`,
  where we are always given an immutable root-hash and we return an updated
  immutable root hash. Thus, we can always walk in time, and due to the
  nature of `ipfs`, anyone can, even without having run the transactions.
  """
  use GenServer

  @type root_hash :: String.t
  @type data_hash :: String.t

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

  def handle_call({:get_all, root_hash}, _from, %{client: client}=state) do
    get_all_result = ipfs_get_all(client, root_hash)

    {:reply, get_all_result, state}
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

  @spec ipfs_new(IPFS.Client.t) :: {:ok, root_hash} | {:error, any()}
  defp ipfs_new(client) do
    with {:ok, %IPFS.Client.PatchObject{hash: root_hash}} <- IPFS.Client.object_new(client) do
      {:ok, root_hash}
    end
  end

  @spec ipfs_put(IPFS.Client.t, root_hash, String.t, String.t) :: {:ok, root_hash} | {:error, any()}
  defp ipfs_put(client, root_hash, path, data) do
    # First, add the object
    with {:ok, data_hash} <- ipfs_save(client, data) do
      # Then, add to hash
      ipfs_add_link(client, root_hash, path, data_hash)
    end
  end

  @spec ipfs_add_link(IPFS.Client.t, root_hash, String.t, String.t) :: {:ok, root_hash} | {:error, any()}
  defp ipfs_add_link(client, root_hash, path, data_hash) do
    with {:ok, %IPFS.Client.PatchObject{hash: new_root_hash}} <- IPFS.Client.object_patch_add_link(client, root_hash, path, data_hash, true) do
      {:ok, new_root_hash}
    end
  end

  @spec ipfs_save(IPFS.Client.t, String.t) :: {:ok, root_hash} | {:error, any()}
  defp ipfs_save(client, data) do
    with {:ok, %IPFS.Client.PatchObject{hash: data_hash}} <- IPFS.Client.object_put(client, data, false) do
      {:ok, data_hash}
    end
  end

  @spec ipfs_put_all(IPFS.Client.t, root_hash, %{}) :: {:ok, binary()} | {:error, any()}
  def ipfs_put_all(client, root_hash, values) do
    Enum.reduce(values, {:ok, root_hash}, fn
      {path, val}, {:ok, current_hash} when val == "" or val == %{} ->
        # Skip blank nodes / maps
        {:ok, current_hash}
      {path, data}, {:ok, current_hash} when is_binary(data) ->
        # Put a simple value
        ipfs_put(client, current_hash, path, data)
      {path, values}, {:ok, current_hash} when is_map(values) ->
        # Put a block of values
        hash_result = case ipfs_get_hash(client, current_hash, path) do
          {:ok, existing_root_hash} -> {:ok, existing_root_hash}
          :not_found -> ipfs_new(client)
          {:error, error} -> {:error, error}
        end

        with {:ok, hash_result_hash} <- hash_result do
          with {:ok, values_root_hash} <- ipfs_put_all(client, hash_result_hash, values) do
            # Link the new block to the current hash
            ipfs_add_link(client, current_hash, path, values_root_hash)
          end
        end
      _, {:error, error} -> {:error, error}
    end)
  end

  @spec ipfs_get_all(IPFS.Client.t, root_hash) :: {:ok, %{}} | {:error, any()}
  def ipfs_get_all(client, root_hash) do
    case do_ipfs_get_all(client, root_hash) do
      {:ok, map} when is_map(map) ->
        {:ok, map}
      {:ok, data} when is_binary(data) ->
        {:error, "expected root, got data: #{inspect data}"}
      {:error, error} -> {:error, error}
    end
  end

  @spec do_ipfs_get_all(IPFS.Client.t, root_hash) :: {:ok, %{} | String.t} | {:error, any()}
  defp do_ipfs_get_all(client, root_hash) do
    case ipfs_retrieve_all(client, root_hash) do
      {:ok, <<>>, links} ->
        # This can probably be parallelized
        Enum.reduce(links, {:ok, %{}}, fn
          {name, hash}, {:ok, map} ->
            with {:ok, result} = do_ipfs_get_all(client, hash) do
              {:ok, Map.put(map, name, result)}
            end
          _, {:error, error} -> {:error, error}
        end)
      {:ok, data, []} ->
        {:ok, data}
      {:ok, data, links} -> {:error, "got both data and links, data=#{inspect data}, links=#{inspect links}"}
      {:error, error} -> {:error, error}
    end
  end

  @spec ipfs_retrieve(IPFS.Client.t, data_hash) :: {:ok, binary()} | {:error, any()}
  defp ipfs_retrieve(client, data_hash) do
    with {:ok, %IPFS.Client.Object{data: data}} <- IPFS.Client.object_get(client, data_hash) do
      {:ok, data}
    end
  end

  @spec ipfs_retrieve_all(IPFS.Client.t, data_hash) :: {:ok, String.t, [{String.t, String.t}]} | {:error, any()}
  defp ipfs_retrieve_all(client, data_hash) do
    with {:ok, %IPFS.Client.Object{data: data, links: links}} <- IPFS.Client.object_get(client, data_hash) do
      simple_links = for link <- links do
        {link.name, link.hash}
      end

      {:ok, data, simple_links}
    end
  end

  @spec ipfs_retrieve_proto(IPFS.Client.t, root_hash) :: {:ok, binary()} | {:error, any()}
  defp ipfs_retrieve_proto(client, hash) do
    with {:ok, proto} <- IPFS.Client.object_get_protobuf(client, hash) do
      {:ok, proto}
    end
  end

  @spec ipfs_get(IPFS.Client.t, root_hash, String.t) :: {:ok, String.t} | :not_found | {:error, any()}
  defp ipfs_get(client, root_hash, path) do
    with {:ok, data_hash} <- ipfs_get_hash(client, root_hash, path) do
      with {:ok, data} <- ipfs_retrieve(client, data_hash) do
        {:ok, data}
      end
    end
  end

  @spec ipfs_get_hash(IPFS.Client.t, root_hash, String.t) :: {:ok, String.t} | :not_found | {:error, any()}
  defp ipfs_get_hash(client, root_hash, path) do
    # Note: This might be slow since we need to walk entire path to find file
    case walk_path(client, path, root_hash) do
      {:ok, [], _found_path, _found_objects, _found_links, data_hash} ->
        {:ok, data_hash}
      {:ok, _looking_path, _found_path, _found_objects, _found_links, _data_hash} -> :not_found
      els -> els
    end
  end

  # Walks down a path as far as possible until it reaches the final path
  # node or, if it fails, returns the last node on that path.
  @spec walk_path(IPFS.Client.t, String.t, root_hash) :: {:ok, [String.t], [String.t], [IPFS.Client.Object.t], root_hash} | {:error, any()}
  defp walk_path(client, path, root_hash) do
    result = do_walk_path(client, Path.split(path), [], [], [], root_hash)

    with {:ok, looking_path, found_path_reverse, found_objects, found_links, root_hash} <- result do
      {:ok, looking_path, found_path_reverse |> Enum.reverse, found_objects, found_links, root_hash}
    end
  end

  @spec do_walk_path(IPFS.Client.t, [String.t], [String.t], [IPFS.Client.Object.t], [String.t], root_hash) :: {:ok, [String.t], [String.t], [IPFS.Client.Object.t], root_hash} | {:error, any()}
  defp do_walk_path(_client, [], found_path, found_objects, found_links, root_hash), do: {:ok, [], found_path, found_objects, found_links, root_hash}
  defp do_walk_path(client, [sub_path|path]=looking_path, found_path, found_objects, found_links, root_hash) do
    ipfs_result = IPFS.Client.object_get(client, root_hash)

    with {:ok, %IPFS.Client.Object{links: links}=object} <- ipfs_result do
      # Look for a link matching sub_path
      link = Enum.find(links, fn link -> link.name == sub_path end)

      # If we find it, recurse, otherwise, we're done
      if link do
        do_walk_path(client, path, [sub_path|found_path], [object|found_objects], [root_hash|found_links], link.hash)
      else
        {:ok, looking_path, found_path, found_objects, found_links, root_hash}
      end
    end
  end

  @spec new(identifier()) :: {:ok, root_hash} | {:error, any()}
  def new(server) do
    GenServer.call(server, :new)
  end

  @spec get(identifier(), root_hash, String.t) :: {:ok, String.t} | :not_found | {:error, any()}
  def get(server, root_hash, path) do
    GenServer.call(server, {:get, root_hash, clean(path)})
  end

  @spec get_all(identifier(), root_hash) :: {:ok, %{}} | {:error, any()}
  def get_all(server, root_hash) do
    GenServer.call(server, {:get_all, root_hash})
  end

  @spec proof(identifier(), root_hash, String.t) :: :ok | :not_found | {:error, any()}
  def proof(server, root_hash, path) do
    GenServer.call(server, {:proof, root_hash, clean(path)})
  end

  @spec put(identifier(), root_hash, String.t, binary()) :: {:ok, root_hash} | {:error, any()}
  def put(server, root_hash, path, value) do
    GenServer.call(server, {:put, root_hash, clean(path), value})
  end

  @spec put_all(identifier(), root_hash, [{String.t, binary()}]) :: {:ok, root_hash} | {:error, any()}
  def put_all(server, root_hash, values) do
    GenServer.call(server, {:put_all, root_hash, values})
  end

  @spec put(identifier(), root_hash, String.t, binary()) :: {:ok, root_hash} | :file_exists | {:error, any()}
  def put_new(server, root_hash, path, value) do
    GenServer.call(server, {:put_new, root_hash, clean(path), value})
  end

  @spec update(identifier(), root_hash, String.t, (String.t -> String.t), [default: String.t, run_update_fn_on_default: boolean()]) :: {:ok, root_hash} | {:error, any()}
  def update(server, root_hash, path, update_fn, opts \\ []) do
    default = Keyword.get(opts, :default, "")
    run_update_fn_on_default = Keyword.get(opts, :run_update_fn_on_default, false)

    GenServer.call(server, {:update, root_hash, clean(path), update_fn, default, run_update_fn_on_default})
  end

  # TODO: Test
  @spec save(identifier(), binary()) :: {:ok, data_hash} | {:error, any()}
  def save(server, data) do
    GenServer.call(server, {:save, data})
  end

  # TODO: Test
  @spec retrieve(identifier(), data_hash) :: {:ok, binary()} | {:error, any()}
  def retrieve(server, data_hash) do
    GenServer.call(server, {:retrieve, data_hash})
  end

  @spec clean(String.t) :: String.t
  defp clean("/" <> path), do: path
  defp clean(path), do: path
end