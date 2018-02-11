defmodule Daisy.Block.Processor do
  @moduledoc """
  `Daisy.Block.Processor` is responsible for processing the transactions of
  a block which producing updated `final_state` and `receipts`. Once a block
  has been fully processed, it can be closed and published to persistent
  storage.
  """

  @doc """
  Helper function to process the block (run the transactions) and save the result
  to IPFS.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.Builder.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.BlockStorage.save_block(genesis_block, storage_pid)
      iex> {:ok, new_block} = Daisy.Block.Builder.new_block(block_hash, storage_pid, [])
      iex> Daisy.Block.Processor.process_and_save_block(new_block, storage_pid, Daisy.Examples.Test.Runner)
      {:ok,
        %Daisy.Data.Block{
          block_number: 1,
          parent_block_hash: "QmYmR75UkB7qNXigPFrX9ajAs1QFHfWXyQRktB4Y5e1Vtr",
          initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
          final_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
          transactions: [],
          receipts: [],
        },
        "QmWbRKtTUQcHB7FU4nFP3LNXeY2EvctexYHoRi1rKizeof"
      }
  """
  @spec process_and_save_block(Daisy.Data.Block.t, identifier(), Daisy.Runner.runner) :: {:ok, Daisy.Data.Block.t, Daisy.Block.block_hash} | {:error, any()}
  def process_and_save_block(block, storage_pid, runner) do
    with {:ok, processed_block} <- process_block(block, storage_pid, runner) do
      with {:ok, block_hash} <- Daisy.Block.BlockStorage.save_block(processed_block, storage_pid) do
        {:ok, processed_block, block_hash}
      end
    end
  end

  @doc """
  For a given block, processes each transaction, computing the receipts
  and `final_storage`.

  ## Examples

      iex> keypair = Daisy.Signature.new_keypair()
      iex> trx_1 = Daisy.Keychain.sign_new_transaction(%Daisy.Data.Invokation{function: "test", args: ["1", "2"]}, keypair)
      iex> trx_2 = Daisy.Keychain.sign_new_transaction(%Daisy.Data.Invokation{function: "test", args: ["3", "4"]}, keypair)
      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.Builder.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.BlockStorage.save_block(genesis_block, storage_pid)
      iex> {:ok, new_block} = Daisy.Block.Builder.new_block(block_hash, storage_pid, [trx_1, trx_2])
      iex> {:ok, processed_block} = Daisy.Block.Processor.process_block(new_block, storage_pid, Daisy.Examples.Test.Runner)
      iex> processed_block.receipts
      [
        %Daisy.Data.Receipt{
          status: 0,
          initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
          final_storage: "QmTvLAzU3Z3Bw72gw7Vqrgxr3orgLRGQQruSS6UXYA617b",
          logs: ["Added 1 and 2 to get 3"],
          debug: "[1, 2, 3]",
        },
        %Daisy.Data.Receipt{
          status: 0,
          initial_storage: "QmTvLAzU3Z3Bw72gw7Vqrgxr3orgLRGQQruSS6UXYA617b",
          final_storage: "QmUxEkEjcqxxdBZwo9B6uPbbEWWnFk72vyRsqHda84YoCj",
          logs: ["Added 3 and 4 to get 7"],
          debug: "[3, 4, 7]",
        }
      ]
  """
  @spec process_block(Daisy.Data.Block.t, identifier(), Daisy.Runner.runner) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def process_block(block, storage_pid, runner) do
    result = Daisy.Runner.process_transactions(block.transactions, storage_pid, block.initial_storage, block.block_number, runner)

    with {:ok, final_storage, receipts} <- result do
      {:ok, %{block | final_storage: final_storage, receipts: receipts}}
    end
  end

  @doc """
  Adds a transaction to a block that has not been processed.

  # TODO: Let's make transactions process as they go!
  """
  @spec add_transaction(Daisy.Data.Block.t, identifier(), Daisy.Data.Transaction.t) :: Daisy.Data.Block.t
  def add_transaction(block, storage_pid, transaction) do
    %{block|
      transactions: block.transactions ++ [transaction]
    }
  end

end