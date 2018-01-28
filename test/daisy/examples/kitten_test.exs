defmodule Daisy.KittenTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, storage_pid} = Daisy.Storage.start_link()

    {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
    {:ok, genesis_block_hash} = Daisy.Block.save_block(genesis_block, storage_pid)
    user_1_keypair = Daisy.Signature.new_keypair()

    {:ok, %{
      storage_pid: storage_pid,
      genesis_block: genesis_block,
      genesis_block_hash: genesis_block_hash,
      user_1_keypair: user_1_keypair}}
  end

  test "it should process a simple block with no transactions", %{
      storage_pid: storage_pid,
      genesis_block: genesis_block,
      genesis_block_hash: genesis_block_hash} do
    {:ok, new_block} = Daisy.Block.new_block(genesis_block_hash, storage_pid, [])

    assert {:ok, processed_block, _new_block_hash} =
      Daisy.Block.process_and_save_block(new_block, storage_pid, Kitten.Runner)

    assert processed_block == %Daisy.Data.Block{
      previous_block_hash: "QmUatzSyhUCBeZvQEM8f56kSbrhEuguKESouHUoqsptz26",
      initial_storage: genesis_block.initial_storage,
      final_storage: genesis_block.initial_storage,
      transactions: [],
      receipts: []
    }
  end

  test "it should process a simple block with one transaction", %{
      storage_pid: storage_pid,
      genesis_block_hash: genesis_block_hash,
      user_1_keypair: user_1_keypair} do

    invokation = Daisy.Data.Invokation.new(function: "spawn", args: ["5000"])

    {:ok, new_block} = Daisy.Block.new_block(
      genesis_block_hash,
      storage_pid, [
        Daisy.Keychain.sign_new_transaction(invokation, user_1_keypair)
    ])

    new_block_initial_storage = new_block.initial_storage

    assert {:ok, processed_block, _new_block_hash} =
      Daisy.Block.process_and_save_block(new_block, storage_pid, Kitten.Runner)

    assert %Daisy.Data.Block{
      initial_storage: ^new_block_initial_storage,
      final_storage: _final_storage,
      transactions: _transactions,
      receipts: receipts
    } = processed_block

    assert [receipt] = receipts # single receipt
    assert receipt.debug =~ "%Kitten.Data.Kitten"
    assert [receipt_log] = receipt.logs
    assert receipt_log =~ "Added new kitten"
    assert receipt.status == 0
    assert receipt.initial_storage == new_block_initial_storage
  end
end