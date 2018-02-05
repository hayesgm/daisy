defmodule Daisy.Examples.KittenTest do
  use ExUnit.Case, async: true
  alias Daisy.Examples.Kitten

  setup do
    {:ok, storage_pid} = Daisy.Storage.start_link()

    {:ok, genesis_block} = Daisy.Block.genesis_block(storage_pid)
    {:ok, genesis_block_hash} = Daisy.Block.save_block(genesis_block, storage_pid)
    user_1_keypair = Daisy.Signature.new_keypair()
    user_2_keypair = Daisy.Signature.new_keypair()

    {:ok, %{
      storage_pid: storage_pid,
      genesis_block: genesis_block,
      genesis_block_hash: genesis_block_hash,
      user_1_keypair: user_1_keypair,
      user_2_keypair: user_2_keypair}}
  end

  test "it should process a simple block with no transactions", %{
      storage_pid: storage_pid,
      genesis_block: genesis_block,
      genesis_block_hash: genesis_block_hash} do
    {:ok, new_block} = Daisy.Block.new_block(genesis_block_hash, storage_pid, [])

    assert {:ok, processed_block, _new_block_hash} =
      Daisy.Block.process_and_save_block(new_block, storage_pid, Kitten.Runner)

    assert processed_block == %Daisy.Data.Block{
      parent_block_hash: "QmUatzSyhUCBeZvQEM8f56kSbrhEuguKESouHUoqsptz26",
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

  test "it should process multiple transactions", %{
      storage_pid: storage_pid,
      genesis_block_hash: genesis_block_hash,
      user_1_keypair: user_1_keypair,
      user_2_keypair: user_2_keypair} do

    invokation_1 = Daisy.Data.Invokation.new(function: "spawn", args: ["5000"])

    {:ok, block_1} = Daisy.Block.new_block(
      genesis_block_hash,
      storage_pid, [
        Daisy.Keychain.sign_new_transaction(invokation_1, user_1_keypair)
    ])

    assert {:ok, block_1, block_1_hash} =
      Daisy.Block.process_and_save_block(block_1, storage_pid, Kitten.Runner)

    # Let's read the kitten from adopted kitties
    assert {:ok, [kitten_uuid]} = Daisy.Block.read(storage_pid, block_1, "orphans", %{}, Kitten.Reader)

    invokation_2 = Daisy.Data.Invokation.new(function: "adopt", args: [kitten_uuid])
    invokation_3 = Daisy.Data.Invokation.new(function: "adopt", args: [kitten_uuid])

    {:ok, block_2} = Daisy.Block.new_block(
      block_1_hash,
      storage_pid, [
        # Notice, we're getting trivial replays-- can't let the same transaction be run twice
        Daisy.Keychain.sign_new_transaction(invokation_1, user_1_keypair),
        Daisy.Keychain.sign_new_transaction(invokation_2, user_1_keypair),
        Daisy.Keychain.sign_new_transaction(invokation_3, user_2_keypair)
    ])

    assert {:ok, block_2, _block_2_hash} =
      Daisy.Block.process_and_save_block(block_2, storage_pid, Kitten.Runner)

    assert [receipt_1, receipt_2, receipt_3] = block_2.receipts

    assert receipt_1.debug =~ "%Kitten.Data.Kitten"
    assert [receipt_1_log] = receipt_1.logs
    assert receipt_1_log =~ "Added new kitten"
    assert receipt_1.status == 0

    assert receipt_2.debug == nil
    assert [receipt_2_log] = receipt_2.logs
    assert receipt_2_log =~ "adopted kitten"
    assert receipt_2.status == 0

    assert receipt_3.debug == nil
    assert [receipt_3_log] = receipt_3.logs
    assert receipt_3_log =~ "not up for adoption"
    assert receipt_3.status == 1 # failure
  end
end