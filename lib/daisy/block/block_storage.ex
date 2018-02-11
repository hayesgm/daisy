defmodule Daisy.Block.BlockStorage do
  @moduledoc """
  `Daisy.Block.BlockStorage` is responsible for loading and saving blocks using
  `Daisy.Storage` mechanisms.
  """
  require Logger

  @type block_reference :: :resolve | :genesis | {:block_hash, Daisy.Block.block_hash}

  @doc """
  Saves a block into IPFS and computes the block hash.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.Builder.genesis_block(storage_pid)
      iex> Daisy.Block.BlockStorage.save_block(genesis_block, storage_pid)
      {:ok, "QmYmR75UkB7qNXigPFrX9ajAs1QFHfWXyQRktB4Y5e1Vtr"}
  """
  @spec save_block(Daisy.Data.Block.t, identifier()) :: {:ok, Daisy.Block.block_hash} | {:error, any()}
  def save_block(block, storage_pid) do
    with {:ok, new_root_hash} <- Daisy.Storage.new(storage_pid) do
      serialized_block = Daisy.Config.get_serializer().serialize(block)

      Daisy.Storage.put_all(
        storage_pid,
        new_root_hash,
        serialized_block
      )
    end
  end

  @doc """
  Loads a complete block from IPFS. De-serialization requires loading all
  data that was stored in IPFS (minus long-term storage), and thus should
  not be called unless necessary.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.Builder.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.BlockStorage.save_block(genesis_block, storage_pid)
      iex> Daisy.Block.BlockStorage.load_block(block_hash, storage_pid)
      {:ok, %Daisy.Data.Block{
        block_number: 0,
        final_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        parent_block_hash: "",
        receipts: [],
        transactions: []
      }}
  """
  @spec load_block(Daisy.Block.block_hash, identifier()) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def load_block(block_hash, storage_pid) do
    with {:ok, values} <- Daisy.Storage.get_all(storage_pid, block_hash) do
      {:ok, Daisy.Config.get_serializer().deserialize(values)}
    end
  end

  @doc """
  Loads a block from a reference, which can be to resolve an IPNS name,
  to load a genesis block or can be a block hash itself.

  TODO: Test
  """
  @spec load_block_reference(block_reference, identifier()) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def load_block_reference(block_reference, storage_pid) do
    block_result = case block_reference do
      :resolve ->
        Logger.debug("[#{__MODULE__}] Looking up for stored block hash in IPNS...")

        case Daisy.Persistence.resolve(Daisy.Persistence) do
          :not_found ->
            # TODO: Really?
            Logger.debug("[#{__MODULE__}] No block found, starting new genesis block")

            Daisy.Block.Builder.genesis_block(storage_pid)
          {:ok, block_hash} ->
            # TODO: New block?
            Logger.debug("[#{__MODULE__}] Creating new block from #{block_hash}")

            Daisy.Block.Builder.new_block(block_hash, storage_pid, [])
          {:error, error} -> raise "[#{__MODULE__}] Error resolving block hash: #{inspect error}"
        end
      :genesis ->
        Logger.debug("[#{__MODULE__}] Loading genesis block, as requested.")

        Daisy.Block.Builder.genesis_block(storage_pid)
      {:block_hash, block_hash} ->
        Logger.debug("[#{__MODULE__}] Loading block #{block_hash}, as requested.")

        load_block(storage_pid, block_hash)
    end
  end

end