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

  @callback run_transaction(Daisy.Data.Invokation.t, identifier(), Daisy.Storage.root_hash, binary()) :: {:ok, Daisy.Runner.transaction_result} | {:error, any()}

  @doc """
  This function runs each of the transactions in the context of the block,
  returning a processed block. The process block has all of the transaction
  receipts and a new final state after the transactions have been run.

  TODO: We shouldn't allow the same transaction to be run multiple times.
  TODO: We should allow this to be run multiple times to add new trxs.
  TODO: This may be where we want to parallelize execution.
  TODO: We probably want to handle errors (like invalid signature) more gracefully.

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, initial_storage} = Daisy.Storage.new(storage_pid)
      iex> keypair = Daisy.RunnerTest.test_keypair()
      iex> trx_1 = Daisy.Keychain.sign_new_transaction(%Daisy.Data.Invokation{function: "test", args: ["1", "2"]}, keypair)
      iex> trx_2 = Daisy.Keychain.sign_new_transaction(%Daisy.Data.Invokation{function: "test", args: ["3", "4"]}, keypair)
      iex> Daisy.Runner.process_transactions([trx_1, trx_2], storage_pid, initial_storage, Daisy.Examples.Test.Runner)
      {:ok,
        "QmUxEkEjcqxxdBZwo9B6uPbbEWWnFk72vyRsqHda84YoCj",
        [
          %Daisy.Data.Receipt{
            status: 0,
            initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
            final_storage: "QmTvLAzU3Z3Bw72gw7Vqrgxr3orgLRGQQruSS6UXYA617b",
            logs: ["Added 1 and 2 to get 3"],
            debug: "[1, 2, 3]"
          },
          %Daisy.Data.Receipt{
            status: 0,
            initial_storage: "QmTvLAzU3Z3Bw72gw7Vqrgxr3orgLRGQQruSS6UXYA617b",
            final_storage: "QmUxEkEjcqxxdBZwo9B6uPbbEWWnFk72vyRsqHda84YoCj",
            logs: ["Added 3 and 4 to get 7"],
            debug: "[3, 4, 7]"
          }
        ]
      }
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

  ## Examples

      iex> {:ok, storage_pid} = Daisy.Storage.start_link()
      iex> {:ok, initial_storage} = Daisy.Storage.new(storage_pid)
      iex> keypair = Daisy.RunnerTest.test_keypair()
      iex> trx_1 = Daisy.Keychain.sign_new_transaction(%Daisy.Data.Invokation{function: "test", args: ["1", "2"]}, keypair)
      iex> Daisy.Runner.process_transaction(trx_1, storage_pid, initial_storage, Daisy.Examples.Test.Runner)
      {:ok, %Daisy.Data.Receipt{
        status: 0,
        initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        final_storage: "QmTvLAzU3Z3Bw72gw7Vqrgxr3orgLRGQQruSS6UXYA617b",
        logs: ["Added 1 and 2 to get 3"],
        debug: "[1, 2, 3]",
      }}
  """
  @spec process_transaction(Daisy.Data.Transaction.t, identifier(), Daisy.Storage.root_hash, runner) :: {:ok, Daisy.Data.Receipt.t} | {:error, any()}
  def process_transaction(transaction, storage_pid, initial_storage, runner) do
    with {:ok, public_key} <- verify_invokation(transaction) do
      with {:ok, transaction_result} <- runner.run_transaction(transaction.invokation, storage_pid, initial_storage, public_key) do
        status = Map.get(transaction_result, :status, :ok)
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

  @doc """
  Verifies an invokation is valid, returning, if valid, the public key
  of the signer.

  ## Examples

      iex> keypair = Daisy.RunnerTest.test_keypair()
      iex> trx_1 = Daisy.Keychain.sign_new_transaction(%Daisy.Data.Invokation{function: "test", args: ["1", "2"]}, keypair)
      iex> Daisy.Runner.verify_invokation(trx_1)
      {:ok, Daisy.RunnerTest.test_public_key()}

      iex> keypair = Daisy.RunnerTest.test_keypair()
      iex> trx_1 = Daisy.Keychain.sign_new_transaction(%Daisy.Data.Invokation{function: "test", args: ["1", "2"]}, keypair)
      iex> Daisy.Runner.verify_invokation(%{trx_1 | signature: %{trx_1.signature | public_key: <<1::512>>}})
      {:error, :invalid_signature}
  """
  @spec verify_invokation(Daisy.Data.Transaction.t) :: {:ok, binary()} | {:error, any()}
  def verify_invokation(%Daisy.Data.Transaction{invokation: invokation, signature: signature}) do
    invokation
    |> Daisy.Data.Invokation.encode()
    |> Daisy.Signature.verify_signature(signature)
  end

end