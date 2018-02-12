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
  @type block_hash :: Daisy.Storage.root_hash

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
    case read_link_from_block_hash(block_hash, storage_pid, "final_storage_link") do
      {:ok, final_storage} -> {:ok, final_storage}
      :not_found -> Daisy.Storage.new(storage_pid)
      els -> els
    end
  end

  @doc """
  Retrieves just the block number of a block.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
      iex> block = %{genesis_block | block_number: 55}
      iex> {:ok, block_hash} = Daisy.Block.save_block(block, storage_pid)
      iex> Daisy.Block.block_number(block_hash, storage_pid)
      {:ok, 55}
  """
  @spec block_number(block_hash, identifier()) :: {:ok, Daisy.Storage.root_hash} | {:error, any()}
  def block_number(block_hash, storage_pid) do
    with {:ok, block_number} <- read_data_from_block_hash(block_hash, storage_pid, "block_number") do
      {:ok, block_number |> String.to_integer}
    end
  end

  # TODO: Make a public function?
  defp read_data_from_block_hash(block_hash, storage_pid, path) do
    case Daisy.Storage.get(storage_pid, block_hash, path) do
      {:ok, value} -> {:ok, value}
      :not_found -> {:error, "cannot find #{path} in stored block `#{block_hash}`"}
      els -> els
    end
  end

  defp read_link_from_block_hash(block_hash, storage_pid, path) do
    case Daisy.Storage.get_hash(storage_pid, block_hash, path) do
      {:ok, value} -> {:ok, value}
      :not_found -> {:error, "cannot find #{path} in stored block `#{block_hash}`"}
      els -> els
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
      iex> {:ok, genesis_block} = Daisy.Block.Builder.genesis_block(storage_pid)
      iex> {:ok, block_hash} = Daisy.Block.BlockStorage.save_block(genesis_block, storage_pid)
      iex> {:ok, new_block} = Daisy.Block.Builder.new_block(block_hash, storage_pid, [trx_1, trx_2])
      iex> {:ok, processed_block, processed_block_hash} = Daisy.Block.Processer.process_and_save_block(new_block, storage_pid, Daisy.Examples.Test.Runner)
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