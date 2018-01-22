defmodule Daisy.Runner do
  @moduledoc """
  `Daisy.Runner` provides a behaviour for implementing the logic of a Daisy VM.
  """

  @type runner :: module()
  @type transaction_result :: %{
    status: atom(),
    final_storage: Daisy.Storage.root_hash,
    logs: [String.t],
    debug: String.t
  }

  @callback run_transaction(Daisy.Data.Transaction.t, identifier(), Daisy.Storage.root_hash) :: {:ok, transaction_result} | {:error, any()}

  @doc """
  Runs each transaction successively until all have been run.

  TODO: This may be where we want to parallelize execution.
  """
  @spec process_transactions([Daisy.Data.Transaction.t], identifier(), Daisy.Storage.root_hash, runner) :: {:ok, Daisy.Storage.root_hash, [Daisy.Data.Receipt.t]} | {:error, any()}
  def process_transactions(transactions, storage_pid, initial_storage, runner) do
    run_result = Enum.reduce(transactions, {:ok, initial_storage, []}, fn
      transaction, {:ok, current_storage, receipts} ->
        with {:ok, receipt} <- process_transaction(transaction, storage_pid, current_storage, runner) do
          {:ok, receipt.final_storage, [receipt | receipts]}
        end
      _, {:error, error} -> {:error, error}
    end)

    with {:ok, final_storage, receipts_rev} <- run_result do
      # We've now processed all transactions and have receipts
      {:ok, final_storage, receipts_rev |> Enum.reverse}
    end
  end

  @doc """
  Runs a single transction and returns a receipt. This receipts includes,
  among other fields, the final state hash which will be used in daisy-chaining
  all transactions.
  """
  @spec process_transaction(Daisy.Data.Transaction.t, identifier(), Daisy.Storage.root_hash, runner) :: {:ok, Daisy.Data.Receipt.t} | {:error, any()}
  def process_transaction(transaction, storage_pid, initial_storage, runner) do
    with {:ok, transaction_result} <- runner.run_transaction(transaction, storage_pid, initial_storage) do
      status = Map.get(transaction_result, :status, :OK)
      final_storage = Map.get(transaction_result, :final_storage, initial_storage)
      logs = Map.get(transaction_result, :logs, [])
      debug = Map.get(transaction_result, :debug, nil)

      {:ok, Daisy.Data.Receipt.new(
        status: Daisy.Data.Receipt.Status.value(status),
        initial_storage: initial_storage,
        final_storage: final_storage,
        logs: logs,
        debug: debug
      )}
    end
  end

end