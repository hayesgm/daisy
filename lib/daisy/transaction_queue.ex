defmodule Daisy.TransactionQueue do
  @moduledoc """

  TODO: We probably shouldn't actually encode/decode in this module
  """

  @storage_key "/transaction_queue"

	@doc """
  Queues an invokation to be run in a future block
  """
  @spec queue(identifier(), Daisy.Storage.root_hash, integer(), binary(), Daisy.Data.Invokation.t) :: {:ok, Daisy.Storage.root_hash} | {:error, any()}
  def queue(storage_pid, storage, block_number, owner, invokation) do
    with {:ok, transaction_queue_list} = Daisy.Storage.ls(storage_pid, storage, "#{@storage_key}/#{block_number}") do
      transaction_queue_count = Enum.count(transaction_queue_list)

      transaction = Daisy.Data.Transaction.new(
        invokation: invokation,
        owner: owner
      )

      Daisy.Storage.put(
        storage_pid,
        storage,
        "#{@storage_key}/#{block_number}/#{transaction_queue_count + 1}",
        Daisy.Config.get_serializer().serialize_transaction(transaction) |> Poison.encode!
      )
    end
  end

  @doc """
  Returns queue of all transactions for a given block number.
  """
  @spec get_queue_for_block(identifier(), Daisy.Storage.root_hash, integer()) :: {:ok, [Daisy.Data.Transaction.t]} | {:error, any()}
  def get_queue_for_block(storage_pid, storage, block_number) do
    serializer = Daisy.Config.get_serializer()

    case Daisy.Storage.get_all(storage_pid, storage, "#{@storage_key}/#{block_number}") do
      {:ok, serialized_transaction_queue} ->
        transaction_queue =
          serialized_transaction_queue
          |> Enum.map(fn {_k, v} -> v end)
          |> Enum.map(&Poison.decode!/1)
          |> Enum.map(&serializer.deserialize_transaction/1)

        {:ok, transaction_queue}
      :not_found -> {:ok, []}
      els -> els
    end
  end
end