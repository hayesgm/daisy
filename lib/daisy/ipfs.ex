defmodule Daisy.IPFS do
  @moduledoc """
  Functions for interacting with IPFS. These are primarily used by
  `Daisy.Storage`.
  """

  @type root_hash :: String.t
  @type data_hash :: String.t

  @empty_data_proto <<8, 1>>

  @spec ipfs_new(IPFS.Client.t) :: {:ok, root_hash} | {:error, any()}
  def ipfs_new(client) do
    with {:ok, %IPFS.Client.PatchObject{hash: root_hash}} <- IPFS.Client.object_put(client, @empty_data_proto, true) do
      {:ok, root_hash}
    end
  end

  @spec ipfs_put(IPFS.Client.t, root_hash, String.t, String.t) :: {:ok, root_hash} | {:error, any()}
  def ipfs_put(client, root_hash, path, data) do
    # First, add the object
    with {:ok, data_hash} <- ipfs_save(client, data) do
      # Then, add to hash
      ipfs_add_link(client, root_hash, path, data_hash)
    end
  end

  @spec ipfs_add_link(IPFS.Client.t, root_hash, String.t, String.t) :: {:ok, root_hash} | {:error, any()}
  def ipfs_add_link(client, root_hash, path, data_hash) do
    with {:ok, %IPFS.Client.PatchObject{hash: new_root_hash}} <- IPFS.Client.object_patch_add_link(client, root_hash, path, data_hash, true) do
      {:ok, new_root_hash}
    end
  end

  @spec ipfs_save(IPFS.Client.t, String.t) :: {:ok, root_hash} | {:error, any()}
  def ipfs_save(client, data) do
    with {:ok, %IPFS.Client.PatchObject{hash: data_hash}} <- IPFS.Client.object_put(client, data, false) do
      {:ok, data_hash}
    end
  end

  @spec ipfs_put_all(IPFS.Client.t, root_hash, %{}) :: {:ok, binary()} | {:error, any()}
  def ipfs_put_all(client, root_hash, values) do
    Enum.reduce(values, {:ok, root_hash}, fn
      {path, val}, {:ok, current_hash} when is_nil(val) or val == "" or val == %{} or val == {:link, ""} ->
        # Skip blank nodes / maps
        {:ok, current_hash}
      {path, {:link, link}}, {:ok, current_hash} ->
        # Directly put a link postfixed with _link
        # TODO: Test
        ipfs_add_link(client, current_hash, path <> "_link", link)
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

  @spec ipfs_get_all(IPFS.Client.t, root_hash) :: {:ok, %{}} | :not_found | {:error, any()}
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
      {:ok, data, links} when data == <<>> or data == @empty_data_proto ->
        # This can probably be parallelized
        Enum.reduce(links, {:ok, %{}}, fn
          {name, hash}, {:ok, map} ->
            # TODO: Maybe come up with a smarter system
            if String.ends_with?(name, "_link") do
              # This just stips the `_link` suffix and does not recurse
              {:ok, Map.put(map, String.replace_suffix(name, "_link", ""), {:link, hash})}
            else
              with {:ok, result} = do_ipfs_get_all(client, hash) do
                {:ok, Map.put(map, name, result)}
              end
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
  def ipfs_retrieve(client, data_hash) do
    with {:ok, %IPFS.Client.Object{data: data}} <- IPFS.Client.object_get(client, data_hash) do
      {:ok, data}
    end
  end

  @spec ipfs_retrieve_all(IPFS.Client.t, data_hash) :: {:ok, String.t, [{String.t, data_hash}]} | {:error, any()}
  def ipfs_retrieve_all(client, data_hash) do
    with {:ok, %IPFS.Client.Object{data: data, links: links}} <- IPFS.Client.object_get(client, data_hash) do
      simple_links = for link <- links do
        {link.name, link.hash}
      end

      {:ok, data, simple_links}
    end
  end

  @spec ipfs_retrieve_proto(IPFS.Client.t, root_hash) :: {:ok, binary()} | {:error, any()}
  def ipfs_retrieve_proto(client, hash) do
    with {:ok, proto} <- IPFS.Client.object_get_protobuf(client, hash) do
      {:ok, proto}
    end
  end

  @spec ipfs_get(IPFS.Client.t, root_hash, String.t) :: {:ok, String.t} | :not_found | {:error, any()}
  def ipfs_get(client, root_hash, path) do
    with {:ok, data_hash} <- ipfs_get_hash(client, root_hash, path) do
      with {:ok, data} <- ipfs_retrieve(client, data_hash) do
        {:ok, data}
      end
    end
  end

  @spec ipfs_get_hash(IPFS.Client.t, root_hash, String.t) :: {:ok, String.t} | :not_found | {:error, any()}
  def ipfs_get_hash(client, root_hash, path) do
    # Note: This might be slow since we need to walk entire path to find file
    case walk_path(client, path, root_hash) do
      {:ok, [], _found_path, _found_objects, _found_links, data_hash} ->
        {:ok, data_hash}
      {:ok, _looking_path, _found_path, _found_objects, _found_links, _data_hash} -> :not_found
      els -> els
    end
  end

  @spec ipfs_get_links(IPFS.Client.t, root_hash, String.t) :: {:ok, [{String.t, data_hash}]} | :not_found | {:error, any()}
  def ipfs_get_links(client, root_hash, path) do
    # Note: This might be slow since we need to walk entire path to find file
    case walk_path(client, path, root_hash) do
      {:ok, [], _found_path, _found_objects, _found_links, data_hash} ->
        with {:ok, _data, links} <- ipfs_retrieve_all(client, data_hash) do
          {:ok, links}
        end
      {:ok, _looking_path, _found_path, _found_objects, _found_links, _data_hash} -> :not_found
      els -> els
    end
  end

  # Walks down a path as far as possible until it reaches the final path
  # node or, if it fails, returns the last node on that path.
  @spec walk_path(IPFS.Client.t, String.t, root_hash) :: {:ok, [String.t], [String.t], [IPFS.Client.Object.t], root_hash} | {:error, any()}
  def walk_path(client, path, root_hash) do
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

end