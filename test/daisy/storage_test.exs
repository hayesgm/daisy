defmodule Daisy.StorageTest do
  use ExUnit.Case, async: true

  setup_all do
    {:ok, server} = Storage.start_link()

    {:ok, %{server: server}}
  end

  @tag :integration
  test "store a new file in ipfs and look it up", %{server: server} do
    {:ok, root_hash} = Storage.new(server)

    assert :not_found == Storage.get(server, root_hash, "players/1")

    {:ok, new_root_hash} = Storage.put(server, root_hash, "players/1", "thomas")
    assert {:ok, "thomas"} == Storage.get(server, new_root_hash, "players/1")

    {:ok, updated_root_hash} = Storage.put(server, new_root_hash, "players/1", "johnson")
    assert {:ok, "johnson"} == Storage.get(server, updated_root_hash, "players/1")
  end

  describe "#new/1" do
    test "it returns the correct base hash", %{server: server} do
      assert {:ok, root_hash} = Storage.new(server)

      assert root_hash == "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n"
    end
  end

  describe "#get/1 and #put/1" do
    test "it returns a file stored at root", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      {:ok, new_root_hash} = Storage.put(server, root_hash, "name", "thomas")
      assert {:ok, "thomas"} == Storage.get(server, new_root_hash, "name")
    end

    test "it returns not found for a file stored at root", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      {:ok, new_root_hash} = Storage.put(server, root_hash, "name", "thomas")
      assert :not_found == Storage.get(server, new_root_hash, "age")
    end

    test "it returns a file stored at deep path", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      {:ok, new_root_hash} = Storage.put(server, root_hash, "players/5/name", "thomas")
      assert {:ok, "thomas"} == Storage.get(server, new_root_hash, "players/5/name")
    end

    test "it returns not found for a file stored at deep path", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      {:ok, new_root_hash} = Storage.put(server, root_hash, "players/5/name", "thomas")
      assert :not_found == Storage.get(server, new_root_hash, "players/7/name")
    end
  end

  describe "#put_new/1" do
    test "it puts a file if new", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      {:ok, new_root_hash} = Storage.put_new(server, root_hash, "players/5/name", "thomas")
      assert {:ok, "thomas"} == Storage.get(server, new_root_hash, "players/5/name")

      {:ok, final_root_hash} = Storage.put_new(server, new_root_hash, "players/5/age", "55")
      assert {:ok, "55"} == Storage.get(server, final_root_hash, "players/5/age")
    end

    test "it fails if file exists new", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      {:ok, new_root_hash} = Storage.put_new(server, root_hash, "players/5/name", "thomas")
      assert {:ok, "thomas"} == Storage.get(server, new_root_hash, "players/5/name")
      assert :file_exists == Storage.put_new(server, new_root_hash, "players/5/name", "thomas")

      {:ok, final_root_hash} = Storage.put_new(server, new_root_hash, "players/5/age", "55")
      assert {:ok, "55"} == Storage.get(server, final_root_hash, "players/5/age")
      assert :file_exists == Storage.put_new(server, final_root_hash, "players/5/age", "55")
    end
  end

  describe "#update/4" do
    test "it puts a new file or updates an existing", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      {:ok, new_root_hash} = Storage.update(server, root_hash, "players/5/name", fn name -> "#{name}, the great" end, "thomas")
      assert {:ok, "thomas"} == Storage.get(server, new_root_hash, "players/5/name")

      {:ok, final_root_hash} = Storage.update(server, new_root_hash, "players/5/name", fn name -> "#{name}, the great" end, "thomas")
      assert {:ok, "thomas, the great"} == Storage.get(server, final_root_hash, "players/5/name")
    end
  end
end