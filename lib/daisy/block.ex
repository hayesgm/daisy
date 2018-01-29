defmodule Daisy.Block do
  @moduledoc """
  Module for handling operations on Daisy-chained blocks.

  This module generally handles how blocks are processed. A block with a given
  set of transactions is processed, which runs all transactions and generates
  receipts for each one. That block is then stored in IPFS with a unix-like
  file system.

  For example, you can view `/ipfs/<block_hash>/transactions` to see the
  transactions which are included in a block, or `ipfs/<block_hash>/final_storage`
  to get the IPFS hash of the storage for the block.
  """
  @serializer Daisy.Serializer.JSONSerializer

  @type block_hash :: Daisy.Storage.root_hash

  @doc """
  Generates an empty genesis block.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> Daisy.Block.genesis_block(storage_pid)
      {:ok, %Daisy.Data.Block{
        previous_block_hash: "",
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
      iex> {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.save_block(genesis_block, storage_pid)
      iex> Daisy.Block.new_block(block_hash, storage_pid, [])
      {:ok,
        %Daisy.Data.Block{final_storage: "",
        initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        previous_block_hash: "QmUatzSyhUCBeZvQEM8f56kSbrhEuguKESouHUoqsptz26",
        receipts: [],
        transactions: []
      }}

      # TODO: Test with transactions
  """
  @spec new_block(block_hash, identifier(), [Daisy.Data.Transaction.t]) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def new_block(previous_block_hash, storage_pid, transactions) do
    with {:ok, previous_block_final_storage} <- final_storage(previous_block_hash, storage_pid) do
      {:ok, Daisy.Data.Block.new(
        previous_block_hash: previous_block_hash,
        initial_storage: previous_block_final_storage,
        transactions: transactions
      )}
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

  @doc """
  Retrieves just the final storage of a block, forgoing pulling in the entire
  contents of the block.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.save_block(genesis_block, storage_pid)
      iex> Daisy.Block.final_storage(block_hash, storage_pid)
      {:ok, "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n"}
  """
  @spec final_storage(block_hash, identifier()) :: {:ok, Daisy.Storage.root_hash} | {:error, any()}
  def final_storage(block_hash, storage_pid) do
    case Daisy.Storage.get(storage_pid, block_hash, "block/final_storage") do
      {:ok, final_storage} -> {:ok, final_storage}
      :not_found -> Daisy.Storage.new(storage_pid)
      els -> els
    end
  end

  @doc """
  Helper function to process the block (run the transactions) and save the result
  to IPFS.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.save_block(genesis_block, storage_pid)
      iex> {:ok, new_block} = Daisy.Block.new_block(block_hash, storage_pid, [])
      iex> Daisy.Block.process_and_save_block(new_block, storage_pid, Daisy.Examples.Test.Runner)
      {:ok,
        %Daisy.Data.Block{
          previous_block_hash: "QmUatzSyhUCBeZvQEM8f56kSbrhEuguKESouHUoqsptz26",
          initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
          final_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
          transactions: [],
          receipts: [],
        },
        "QmdU2KH5vCFFdbWonT1GB7y15AZZoxsthViDuBLa5EwhAm"
      }
  """
  @spec process_and_save_block(Daisy.Data.Block.t, identifier(), Daisy.Runner.runner) :: {:ok, Daisy.Data.Block.t, block_hash} | {:error, any()}
  def process_and_save_block(block, storage_pid, runner) do
    with {:ok, processed_block} <- process_block(block, storage_pid, runner) do
      with {:ok, block_hash} <- save_block(processed_block, storage_pid) do
        {:ok, processed_block, block_hash}
      end
    end
  end

  @doc """
  Saves a block into IPFS and computes the block hash.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
      iex> Daisy.Block.save_block(genesis_block, storage_pid)
      {:ok, "QmUatzSyhUCBeZvQEM8f56kSbrhEuguKESouHUoqsptz26"}
  """
  @spec save_block(Daisy.Data.Block.t, identifier()) :: {:ok, block_hash} | {:error, any()}
  def save_block(block, storage_pid) do
    with {:ok, new_root_hash} <- Daisy.Storage.new(storage_pid) do
      serialized_block = @serializer.serialize(block)

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
      iex> {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.save_block(genesis_block, storage_pid)
      iex> Daisy.Block.load_block(storage_pid, block_hash)
      {:ok, %Daisy.Data.Block{
        final_storage: nil,
        initial_storage: nil,
        previous_block_hash: "",
        receipts: [],
        transactions: []
      }}
  """
  @spec load_block(identifier(), block_hash) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def load_block(storage_pid, block_hash) do
    with {:ok, values} <- Daisy.Storage.get_all(storage_pid, block_hash) do
      block_values = values["block"]
      block = @serializer.deserialize(block_values)

      {:ok, block}
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
      iex> {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.save_block(genesis_block, storage_pid)
      iex> {:ok, new_block} = Daisy.Block.new_block(block_hash, storage_pid, [trx_1, trx_2])
      iex> {:ok, processed_block} = Daisy.Block.process_block(new_block, storage_pid, Daisy.Examples.Test.Runner)
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
    result = Daisy.Runner.process_transactions(block.transactions, storage_pid, block.initial_storage, runner)

    with {:ok, final_storage, receipts} <- result do
      {:ok, %{block | final_storage: final_storage, receipts: receipts}}
    end
  end

  @doc """
  Executes a function to read its value (without affecting any state).

  TODO: What types should args and the result be? Currently, we have strings???

  ## Examples

      iex> keypair = Daisy.Signature.new_keypair()
      iex> trx_1 = Daisy.Keychain.sign_new_transaction(%Daisy.Data.Invokation{function: "test", args: ["1", "2"]}, keypair)
      iex> trx_2 = Daisy.Keychain.sign_new_transaction(%Daisy.Data.Invokation{function: "test", args: ["3", "4"]}, keypair)
      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.save_block(genesis_block, storage_pid)
      iex> {:ok, new_block} = Daisy.Block.new_block(block_hash, storage_pid, [trx_1, trx_2])
      iex> {:ok, processed_block, processed_block_hash} = Daisy.Block.process_and_save_block(new_block, storage_pid, Daisy.Examples.Test.Runner)
      iex> Daisy.Block.read(storage_pid, processed_block, "result", [], Daisy.Examples.Test.Reader)
      {:ok, 7}
      iex> Daisy.Block.read(storage_pid, processed_block_hash, "result", [], Daisy.Examples.Test.Reader)
      {:ok, 7}
  """
  @spec read(identifier(), Daisy.Data.Block.t | block_hash, String.t, [String.t], Daisy.Reader.reader) :: {:ok, any()} | {:error, any()}
  def read(storage_pid, %Daisy.Data.Block{final_storage: final_storage}, function, args, reader) when final_storage != nil and final_storage != "" do
    do_read(storage_pid, final_storage, function, args, reader)
  end

  def read(storage_pid, %Daisy.Data.Block{initial_storage: initial_storage}, function, args, reader) when initial_storage != nil and initial_storage != "" do
    do_read(storage_pid, initial_storage, function, args, reader)
  end

  def read(storage_pid, block_hash, function, args, reader) do
    with {:ok, final_storage} <- final_storage(block_hash, storage_pid) do
      do_read(storage_pid, final_storage, function, args, reader)
    end
  end

  @spec do_read(identifier(), block_hash, String.t, [String.t], Daisy.Reader.reader) :: String.t
  defp do_read(storage_pid, block_hash, function, args, reader) do
    Daisy.Reader.read(storage_pid, block_hash, function, args, reader)
  end

end