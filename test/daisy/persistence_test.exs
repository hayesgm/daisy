defmodule Daisy.PersistenceTest do
  use ExUnit.Case, async: true
  doctest Daisy.Persistence

  setup do
    {:ok, storage_pid} = Daisy.Storage.start_link()
    {:ok, persistence_pid} = Daisy.Persistence.start_link()

    {:ok, %{
      storage_pid: storage_pid,
      persistence_pid: persistence_pid,
    }}
  end

  describe "#publish/2" do
    test "it should publish an object", %{storage_pid: storage_pid, persistence_pid: persistence_pid} do
      {:ok, data_hash} = Daisy.Storage.save(storage_pid, "test")
      ipfs_link = "/ipfs/#{data_hash}"
      assert {:ok, _name, ^ipfs_link} = Daisy.Persistence.publish(persistence_pid, data_hash)

      assert {:ok, data_hash} == Daisy.Persistence.resolve(persistence_pid)
    end
  end

  describe "#resolve/1" do
    test "it should persist an object (posted elsewhere)" do
      {:ok, persistence_pid} = Daisy.Persistence.start_link(key_id: "QmdkpdEigZ677wg9ViUm8Vu2znroKSFC9Fu8ptaEqgX9Rz")

      assert {:ok, "QmVuetiw5MsWeKJKyKi9XE5UKTa47668ZV4MQVEJqe6pnL"} == Daisy.Persistence.resolve(persistence_pid)
    end

    test "it should handle not found", %{persistence_pid: persistence_pid} do
      assert :not_found == Daisy.Persistence.resolve(persistence_pid)
    end
  end
end