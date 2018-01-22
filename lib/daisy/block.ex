defmodule Daisy.Block do
  @moduledoc """
  Module for handling operations on blocks. The data for blocks is stored in
  a `Daisy.Data.Block` proto.
  """

  @doc """
  Generates an empty genesis block.
  """
  @spec genesis_block(identifier()) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def genesis_block(storage_pid) do
    with {:ok, initial_storage} <- Daisy.Storage.new(storage_pid) do
      {:ok, Daisy.Data.Block.new(
        initial_storage: initial_storage,
        final_storage: initial_storage,
        transactions: []
      )}
    end
  end

  @doc """
  Generates a new block with the given transactions from a previous block.
  """
  @spec new_block(Daisy.Storage.root_hash, identifier(), [Daisy.Data.Transaction.t]) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def new_block(previous_block_hash, storage_pid, transactions) do
    with {:ok, block_data} <- Daisy.Storage.retrieve(storage_pid, previous_block_hash) do
      previous_block = Daisy.Data.Block.decode(block_data)

      Daisy.Data.Block.new(
        previous_block_hash: previous_block_hash,
        initial_storage: previous_block.final_storage,
        transactions: transactions
      )
    end
  end

  @doc """
  Helper function to process the block (run the transactions) and save the result
  to IPFS.
  """
  @spec process_and_save_block(Daisy.Data.Block.t, identifier(), Daisy.Runner.runner) :: {:ok, Daisy.Data.Block.t, Daisy.Storage.root_hash} | {:error, any()}
  def process_and_save_block(block, storage_pid, runner) do
    with {:ok, processed_block} <- process_block(block, storage_pid, runner) do
      with {:ok, data_hash} <- save_block(block, storage_pid) do
        {:ok, processed_block, data_hash}
      end
    end
  end

  @doc """
  Saves a block into IPFS and computes the block hash.
  """
  @spec save_block(Daisy.Data.Block.t, identifier()) :: {:ok, Daisy.Storage.root_hash} | {:error, any()}
  def save_block(block, storage_pid) do
    encoded_block = Daisy.Data.Block.encode(block)

    Daisy.Storage.save(storage_pid, encoded_block)
  end

  @doc """
  For a given block, processes each transaction, computing the receipts
  and `final_storage`.
  """
  @spec process_block(Daisy.Data.Block.t, identifier(), Daisy.Runner.runner) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def process_block(block, storage_pid, runner) do
    result = Daisy.Runner.process_transactions(block.transactions, storage_pid, block.initial_storage, runner)

    with {:ok, final_storage, receipts} <- result do
      {:ok, %{block | final_storage: final_storage, receipts: receipts}}
    end
  end

  @doc """
  Executes a function to read its value (without affecting any state).

  TODO: What types should args and the result be? Currently, we have strings???
  """
  @spec read(Daisy.Data.Block.t, identifier(), Daisy.Reader.reader, String.t, [String.t]) :: String.t
  def read(block, storage_pid, reader, function, args) do
    Daisy.Reader.read(block, storage_pid, reader, function, args)
  end

end