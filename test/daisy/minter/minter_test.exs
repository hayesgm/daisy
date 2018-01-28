defmodule Daisy.MinterTest do
  use ExUnit.Case, async: true
  doctest Daisy.Minter
  alias Daisy.Minter

  setup do
    {:ok, storage_pid} = Daisy.Storage.start_link()
    {:ok, minter_pid} = Daisy.Minter.start_link(
      storage_pid,
      :genesis,
      Daisy.Examples.Test.Runner,
      Daisy.Examples.Test.Reader)

    {:ok, %{
      minter_pid: minter_pid
    }}
  end

  describe "#get_block/1" do
    test "it returns the current block", %{minter_pid: minter_pid} do
      assert %Daisy.Data.Block{
        final_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        previous_block_hash: "",
        receipts: [],
        transactions: []
      } == Minter.get_block(minter_pid)
    end
  end

  describe "#mine_block/1" do
    test "should mine a block", %{minter_pid: minter_pid} do
      assert "QmUatzSyhUCBeZvQEM8f56kSbrhEuguKESouHUoqsptz26" == Minter.mine_block(minter_pid)

      assert %Daisy.Data.Block{
        final_storage: "",
        initial_storage: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
        previous_block_hash: "QmUatzSyhUCBeZvQEM8f56kSbrhEuguKESouHUoqsptz26",
        receipts: [],
        transactions: []
      } == Minter.get_block(minter_pid)
    end
  end

  describe "#add_transaction/2" do
    test "should add a transaction to block", %{minter_pid: minter_pid} do
      invokation = Daisy.Data.Invokation.new(function: "test", args: ["7", "44"])
      keypair = Daisy.Signature.new_keypair()
      transaction = Daisy.Keychain.sign_new_transaction(invokation, keypair)

      assert %Daisy.Data.Block{
        transactions: [^transaction]
      } = Minter.add_transaction(minter_pid, transaction)

      assert %Daisy.Data.Block{
        transactions: [^transaction]
      } = Minter.get_block(minter_pid)

      block_hash = Minter.mine_block(minter_pid)

      assert %Daisy.Data.Block{
        previous_block_hash: ^block_hash,
        receipts: [],
        transactions: []
      } = Minter.get_block(minter_pid)
    end
  end

  describe "#read/3" do
    test "should add a transaction to block", %{minter_pid: minter_pid} do
      invokation = Daisy.Data.Invokation.new(function: "test", args: ["7", "44"])
      keypair = Daisy.Signature.new_keypair()
      transaction = Daisy.Keychain.sign_new_transaction(invokation, keypair)

      Minter.add_transaction(minter_pid, transaction)
      Minter.mine_block(minter_pid)

      assert {:ok, 51} == Minter.read(minter_pid, "result", %{})
    end
  end

  describe "#start_mining/2" do
    test "should begin to mine blocks", %{minter_pid: minter_pid} do
      block_1 = Minter.get_block(minter_pid)

      Minter.start_mining(minter_pid, 500)

      :timer.sleep(600)

      block_2 = Minter.get_block(minter_pid)

      assert block_2.previous_block_hash != ""

      :timer.sleep(600)

      block_3 = Minter.get_block(minter_pid)

      assert block_3.previous_block_hash != ""
      assert block_3.previous_block_hash != block_2.previous_block_hash
    end
  end
end