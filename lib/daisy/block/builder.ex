defmodule Daisy.Block.Builder do
  @moduledoc """
  `Daisy.Block.Builder` is responsible for constructing new blocks. These
  blocks will either be genesis blocks or a new block based on a previous
  block.
  """

  @doc """
  Generates an empty genesis block.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> Daisy.Block.Builder.genesis_block(storage_pid)
      {:ok, %Daisy.Data.Block{
        block_number: 1,
        parent_block_hash: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        final_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        transactions: [],
        receipts: [],
      }}
  """
  @spec genesis_block(identifier()) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def genesis_block(storage_pid) do
    with {:ok, initial_storage} <- Daisy.Storage.new(storage_pid) do
      {:ok, Daisy.Data.Block.new(
        block_number: 1,
        parent_block_hash: initial_storage,
        initial_storage: initial_storage,
        final_storage: initial_storage,
        transactions: []
      )}
    end
  end

  @doc """
  Generates a new block with the given transactions from a previous block.

  TODO: Allow from block or block_hash?

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.Builder.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.BlockStorage.save_block(genesis_block, storage_pid)
      iex> Daisy.Block.Builder.new_block(block_hash, storage_pid, [])
      {:ok,
        %Daisy.Data.Block{
          block_number: 1,
          final_storage: "",
          initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
          parent_block_hash: "QmYmR75UkB7qNXigPFrX9ajAs1QFHfWXyQRktB4Y5e1Vtr",
          receipts: [],
          transactions: []
      }}

      # TODO: Test with transactions
  """
  @spec new_block(Daisy.Block.block_hash, identifier(), [Daisy.Data.Transaction.t]) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def new_block(parent_block_hash, storage_pid, transactions) do
    with {:ok, previous_block_final_storage} <- Daisy.Block.final_storage(parent_block_hash, storage_pid) do
      with {:ok, previous_block_number} <- Daisy.Block.block_number(parent_block_hash, storage_pid) do
        block_number = previous_block_number + 1

        with {:ok, transaction_queue} <- Daisy.TransactionQueue.get_queue_for_block(storage_pid, previous_block_final_storage, block_number) do
          {:ok, Daisy.Data.Block.new(
            block_number: block_number,
            parent_block_hash: parent_block_hash,
            initial_storage: previous_block_final_storage,
            transactions: transaction_queue ++ transactions,
          )}
        end
      end
    end
  end
end