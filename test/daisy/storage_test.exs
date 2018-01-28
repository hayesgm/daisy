defmodule Daisy.StorageTest do
  use ExUnit.Case, async: true
  use Bitwise

  require Logger

  alias Daisy.{Storage, Prover}

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

      {:ok, new_root_hash} = Storage.update(server, root_hash, "players/5/name", fn name -> "#{name}, the great" end, default: "thomas")
      assert {:ok, "thomas"} == Storage.get(server, new_root_hash, "players/5/name")

      {:ok, final_root_hash} = Storage.update(server, new_root_hash, "players/5/name", fn name -> "#{name}, the great" end, default: "thomas")
      assert {:ok, "thomas, the great"} == Storage.get(server, final_root_hash, "players/5/name")
    end
  end

  describe "#put_all/3" do
    test "it should add a whole tree of values", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      {:ok, root_hash_1} = Storage.put_all(server, root_hash, %{
        "coaches" => %{},
        "meta" => "",
        "players" => %{
          "tim" => %{
            "name" => "tim",
            "scores" => %{
              "0" => %{
                "date" => "Jan 1",
                "score" => "15"
              },
              "1" => %{
                "date" => "Jan 2",
                "score" => "20",
                "extra" => %{}
              }
            }
          }
        }
      })

      assert {:ok, "tim"} == Storage.get(server, root_hash_1, "players/tim/name")
      assert :not_found == Storage.get(server, root_hash_1, "players/tim/age")
      assert {:ok, ""} == Storage.get(server, root_hash_1, "players/tim/scores")
      assert {:ok, ""} == Storage.get(server, root_hash_1, "players/tim/scores/0")
      assert {:ok, "Jan 1"} == Storage.get(server, root_hash_1, "players/tim/scores/0/date")
      assert {:ok, "15"} == Storage.get(server, root_hash_1, "players/tim/scores/0/score")
      assert {:ok, ""} == Storage.get(server, root_hash_1, "players/tim/scores/1")
      assert {:ok, "Jan 2"} == Storage.get(server, root_hash_1, "players/tim/scores/1/date")
      assert {:ok, "20"} == Storage.get(server, root_hash_1, "players/tim/scores/1/score")
    end

    test "it should handle updates gracefully", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      {:ok, root_hash_1} = Storage.put_all(server, root_hash, %{
        "players" => %{
          "tim" => %{
            "name" => "tim",
            "scores" => %{
              "0" => %{
                "date" => "Jan 1",
                "score" => "15"
              },
              "1" => %{
                "date" => "Jan 2",
                "score" => "20"
              }
            }
          }
        }
      })

      {:ok, root_hash_2} = Storage.put_all(server, root_hash_1, %{
        "players" => %{
          "tim" => %{
            "name" => "timothy",
            "scores" => %{
              "0" => %{
                "date" => "Jan 1",
                "score" => "15"
              },
              "2" => %{
                "date" => "Jan 3",
                "score" => "30"
              }
            }
          }
        }
      })

      assert {:ok, "timothy"} == Storage.get(server, root_hash_2, "players/tim/name")
      assert :not_found == Storage.get(server, root_hash_2, "players/tim/age")
      assert {:ok, ""} == Storage.get(server, root_hash_2, "players/tim/scores")
      assert {:ok, ""} == Storage.get(server, root_hash_2, "players/tim/scores/0")
      assert {:ok, "Jan 1"} == Storage.get(server, root_hash_2, "players/tim/scores/0/date")
      assert {:ok, "15"} == Storage.get(server, root_hash_2, "players/tim/scores/0/score")
      assert {:ok, ""} == Storage.get(server, root_hash_2, "players/tim/scores/1")
      assert {:ok, "Jan 2"} == Storage.get(server, root_hash_2, "players/tim/scores/1/date")
      assert {:ok, "20"} == Storage.get(server, root_hash_2, "players/tim/scores/1/score")
      assert {:ok, ""} == Storage.get(server, root_hash_2, "players/tim/scores/2")
      assert {:ok, "Jan 3"} == Storage.get(server, root_hash_2, "players/tim/scores/2/date")
      assert {:ok, "30"} == Storage.get(server, root_hash_2, "players/tim/scores/2/score")
    end
  end

  describe "#get_all/2" do
    test "it should return all values", %{server: server} do
      {:ok, root_hash} = Storage.new(server)

      map = %{
        "players" => %{
          "tim" => %{
            "name" => "tim",
            "scores" => %{
              "0" => %{
                "date" => "Jan 1",
                "score" => "15"
              },
              "1" => %{
                "date" => "Jan 2",
                "score" => "20"
              }
            }
          }
        }
      }

      {:ok, root_hash_1} = Storage.put_all(server, root_hash, map)

      assert Storage.get_all(server, root_hash) == {:ok, %{}}
      assert Storage.get_all(server, root_hash_1) == {:ok, map}
    end
  end

  describe "#proof/3" do
    test "it proves value at a simple path", %{server: server} do
      {:ok, root_hash} = Storage.new(server)
      id = "id#{:rand.uniform(1000000)}"
      attrs = "name:johnny#{:rand.uniform(1000000)}"
      path = "football/players/#{id}"

      {:ok, root_hash} = Storage.put(server, root_hash, path, attrs)

      {:ok, proof} = Storage.proof(server, root_hash, path)

      assert :qed == Prover.verify_proof!(root_hash, path, attrs, proof)
    end

    test "it proves value at a variety of forked paths", %{server: server} do
      {:ok, root_hash_1} = Storage.new(server)

      attrs_1 = "name:johnny#{:rand.uniform(1000000)}"
      path_1 = "football/players/id#{:rand.uniform(1000000)}"

      attrs_2 = "name:randy#{:rand.uniform(1000000)}"
      path_2 = "football/players/id#{:rand.uniform(1000000)}"

      attrs_3 = "name:thom#{:rand.uniform(1000000)}"
      path_3 = "football/players/id#{:rand.uniform(1000000)}"

      attrs_4 = "name:big_tim#{:rand.uniform(1000000)}"
      path_4 = "football/coaches/id#{:rand.uniform(1000000)}"

      attrs_5 = "name:slugger#{:rand.uniform(1000000)}"
      path_5 = "baseball/players/id#{:rand.uniform(1000000)}"

      {:ok, root_hash_2} = Storage.put(server, root_hash_1, path_1, attrs_1)
      {:ok, root_hash_3} = Storage.put(server, root_hash_2, path_2, attrs_2)
      {:ok, root_hash_4} = Storage.put(server, root_hash_3, path_3, attrs_3)
      {:ok, root_hash_5} = Storage.put(server, root_hash_4, path_4, attrs_4)
      {:ok, root_hash_6} = Storage.put(server, root_hash_5, path_5, attrs_5)

      {:ok, proof_1} = Storage.proof(server, root_hash_6, path_1)
      assert :qed == Prover.verify_proof!(root_hash_6, path_1, attrs_1, proof_1)
      assert :invalid_data_proof == Prover.verify_proof!(root_hash_6, path_1, "bad" <> attrs_1, proof_1)

      {:ok, proof_2} = Storage.proof(server, root_hash_6, path_2)
      assert :qed == Prover.verify_proof!(root_hash_6, path_2, attrs_2, proof_2)
      assert :invalid_data_proof == Prover.verify_proof!(root_hash_6, path_2, "bad" <> attrs_2, proof_2)

      {:ok, proof_3} = Storage.proof(server, root_hash_6, path_3)
      assert :qed == Prover.verify_proof!(root_hash_6, path_3, attrs_3, proof_3)
      assert :invalid_data_proof == Prover.verify_proof!(root_hash_6, path_3, "bad" <> attrs_3, proof_3)

      {:ok, proof_4} = Storage.proof(server, root_hash_6, path_4)
      assert :qed == Prover.verify_proof!(root_hash_6, path_4, attrs_4, proof_4)
      assert :invalid_data_proof == Prover.verify_proof!(root_hash_6, path_4, "bad" <> attrs_4, proof_4)

      {:ok, proof_5} = Storage.proof(server, root_hash_6, path_5)
      assert :qed == Prover.verify_proof!(root_hash_6, path_5, attrs_5, proof_5)
      assert :invalid_data_proof == Prover.verify_proof!(root_hash_6, path_5, "bad" <> attrs_5, proof_5)
    end

    test "it doesn't prove incorrect value at simple path", %{server: server} do
      {:ok, root_hash} = Storage.new(server)
      id = "id#{:rand.uniform(1000000)}"
      attrs = "name:johnny#{:rand.uniform(1000000)}"
      path = "football/players/#{id}"

      {:ok, root_hash} = Storage.put(server, root_hash, path, attrs)

      {:ok, proof} = Storage.proof(server, root_hash, path)

      assert :invalid_data_proof == Prover.verify_proof!(root_hash, path, "name:ronny7", proof)
    end

    test "it doesn't prove correct value at incorrect path", %{server: server} do
      {:ok, root_hash} = Storage.new(server)
      id = "id#{:rand.uniform(1000000)}"
      attrs = "name:johnny#{:rand.uniform(1000000)}"
      path = "football/players/#{id}"
      fake_path_1 = "football/coaches/#{id}"
      fake_path_2 = "baseball/players/#{id}"
      fake_path_3 = "baseball/coaches/red"

      {:ok, root_hash} = Storage.put(server, root_hash, path, attrs)

      {:ok, proof} = Storage.proof(server, root_hash, path)

      assert {:invalid_proof, "coaches"} == Prover.verify_proof!(root_hash, fake_path_1, attrs, proof)
      assert {:invalid_proof, "baseball"} == Prover.verify_proof!(root_hash, fake_path_2, attrs, proof)
      assert {:invalid_proof, "red"} == Prover.verify_proof!(root_hash, fake_path_3, attrs, proof)
    end
  end

end