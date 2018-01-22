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

  def start_link(host \\ "localhost", port \\ "5001") do
    GenServer.start_link(__MODULE__, {host, port})
  end

  def init({host, port}) do
    client = IPFS.Client.new(host, port)

    {:ok, %{
      client: client
    }}
  end

  def handle_call(:new, _from, %{client: client}=state) do
    result = with {:ok, %IPFS.Client.PatchObject{hash: root_hash}} <- IPFS.Client.object_new(client) do
      {:ok, root_hash}
    end

    {:reply, result, state}
  end

  def handle_call({:put, root_hash, path, data}, _from, %{client: client}=state) do
    put_result = ipfs_put(client, root_hash, path, data)

    {:reply, put_result, state}
  end

  def handle_call({:put_new, root_hash, path, data}, _from, %{client: client}=state) do
    # Note: This might be slow since we need to walk entire path to find file
    result = case walk_path(client, path, root_hash) do
      {:ok, [], _found_path, _data_hash} ->
        :file_exists
      {:ok, _looking_path, _found_path, _sub_root_hash} ->
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

  # Walks down a path as far as possible until it reaches the final path
  # node or, if it fails, returns the last node on that path.
  @spec walk_path(IPFS.Client.t, String.t, root_hash) :: {:ok, [String.t], [String.t], root_hash} | {:error, any()}
  defp walk_path(client, path, root_hash) do
    result = do_walk_path(client, Path.split(path), [], root_hash)

    with {:ok, looking_path, found_path_reverse, root_hash} <- result do
      {:ok, looking_path, found_path_reverse |> Enum.reverse, root_hash}
    end
  end

  @spec ipfs_put(IPFS.Client.t, root_hash, String.t, String.t) :: {:ok, root_hash} | {:error, any()}
  defp ipfs_put(client, root_hash, path, data) do
    # First, add the object
    with {:ok, data_hash} <- ipfs_save(client, data) do
      # Then, add to hash
      with {:ok, %IPFS.Client.PatchObject{hash: new_root_hash}} <- IPFS.Client.object_patch_add_link(client, root_hash, path, data_hash, true) do
        {:ok, new_root_hash}
      end
    end
  end

  @spec ipfs_save(IPFS.Client.t, String.t) :: {:ok, root_hash} | {:error, any()}
  defp ipfs_save(client, data) do
    with {:ok, %IPFS.Client.PatchObject{hash: data_hash}} <- IPFS.Client.object_put(client, data, false) do
      {:ok, data_hash}
    end
  end

  @spec ipfs_retrieve(IPFS.Client.t, data_hash) :: {:ok, binary()} | {:error, any()}
  defp ipfs_retrieve(client, data_hash) do
    with {:ok, %IPFS.Client.Object{data: data}} <- IPFS.Client.object_get(client, data_hash) do
      {:ok, data}
    end
  end

  @spec ipfs_get(IPFS.Client.t, root_hash, String.t) :: {:ok, String.t} | :not_found | {:error, any()}
  defp ipfs_get(client, root_hash, path) do
    # Note: This might be slow since we need to walk entire path to find file
    case walk_path(client, path, root_hash) do
      {:ok, [], _found_path, data_hash} ->
        with {:ok, data} <- ipfs_retrieve(client, data_hash) do
          {:ok, data}
        end
      {:ok, _looking_path, _found_path, _data_hash} -> :not_found
      els -> els
    end
  end

  @spec do_walk_path(IPFS.Client.t, [String.t], [], root_hash) :: {:ok, [String.t], [String.t], root_hash} | {:error, any()}
  defp do_walk_path(_client, [], found_path, root_hash), do: {:ok, [], found_path, root_hash}
  defp do_walk_path(client, [sub_path|path]=looking_path, found_path, root_hash) do
    ipfs_result = IPFS.Client.object_get(client, root_hash)

    with {:ok, %IPFS.Client.Object{links: links}} <- ipfs_result do
      # Look for a link matching sub_path
      link = Enum.find(links, fn link -> link.name == sub_path end)

      # If we find it, recurse, otherwise, we're done
      if link do
        do_walk_path(client, path, [sub_path|found_path], link.hash)
      else
        {:ok, looking_path, found_path, root_hash}
      end
    end
  end

  @spec new(identifier()) :: {:ok, root_hash} | {:error, any()}
  def new(server) do
    GenServer.call(server, :new)
  end

  @spec get(identifier(), root_hash, String.t) :: {:ok, String.t} | :not_found | {:error, any()}
  def get(server, root_hash, path) do
    GenServer.call(server, {:get, root_hash, path})
  end

  @spec put(identifier(), root_hash, String.t, binary()) :: {:ok, root_hash} | {:error, any()}
  def put(server, root_hash, path, value) do
    GenServer.call(server, {:put, root_hash, path, value})
  end

  @spec put(identifier(), root_hash, String.t, binary()) :: {:ok, root_hash} | :file_exists | {:error, any()}
  def put_new(server, root_hash, path, value) do
    GenServer.call(server, {:put_new, root_hash, path, value})
  end

  @spec update(identifier(), root_hash, String.t, (String.t -> String.t), [default: String.t, run_update_fn_on_default: boolean()]) :: {:ok, root_hash} | {:error, any()}
  def update(server, root_hash, path, update_fn, opts \\ []) do
    default = Keyword.get(opts, :default, "")
    run_update_fn_on_default = Keyword.get(opts, :run_update_fn_on_default, false)

    GenServer.call(server, {:update, root_hash, path, update_fn, default, run_update_fn_on_default})
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
end