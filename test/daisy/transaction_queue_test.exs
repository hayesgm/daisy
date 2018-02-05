defmodule Daisy.TransactionQueueTest do
  use ExUnit.Case, async: true
  doctest Daisy.TransactionQueue
  alias Daisy.TransactionQueue

  setup_all do
    {:ok, storage_pid} = Daisy.Storage.start_link()
    {:ok, root_hash} = Daisy.Storage.new(storage_pid)

    {:ok, %{
      storage_pid: storage_pid,
      root_hash: root_hash
    }}
  end

  describe "#queue/5" do
    test "it can enqueue and dequeue invokations", %{storage_pid: storage_pid, root_hash: root_hash} do
      invokation = Daisy.Data.Invokation.new(
        function: "abc",
        args: ["1", "2", "3"]
      )
      {:ok, root_hash_1} = TransactionQueue.queue(storage_pid, root_hash, 5, <<1>>, invokation)

      assert {:ok, []} == TransactionQueue.get_queue_for_block(storage_pid, root_hash, 5)
      assert {:ok, [
        %Daisy.Data.Transaction{
          invokation: invokation,
          owner: <<1>>,
          signature: Daisy.Data.Signature.new()
        }]
      } == TransactionQueue.get_queue_for_block(storage_pid, root_hash_1, 5)

      assert {:ok, []} == TransactionQueue.get_queue_for_block(storage_pid, root_hash_1, 6)
    end
  end

  describe "#get_queue_for_block/3" do
    test "it has correct transaction", %{storage_pid: storage_pid, root_hash: root_hash} do
      invokation_1 = Daisy.Data.Invokation.new(
        function: "abc",
        args: ["1", "2", "3"]
      )
      invokation_2 = Daisy.Data.Invokation.new(
        function: "def",
        args: ["1"]
      )
      {:ok, root_hash_1} = TransactionQueue.queue(storage_pid, root_hash, 5, <<1>>, invokation_1)
      {:ok, root_hash_2} = TransactionQueue.queue(storage_pid, root_hash_1, 5, <<2>>, invokation_2)

      assert {:ok, [
        %Daisy.Data.Transaction{
          invokation: invokation_1,
          owner: <<1>>,
          signature: Daisy.Data.Signature.new()
        },
        %Daisy.Data.Transaction{
          invokation: invokation_2,
          owner: <<2>>,
          signature: Daisy.Data.Signature.new()
        }]
      } == TransactionQueue.get_queue_for_block(storage_pid, root_hash_2, 5)
    end
  end

end