defmodule Daisy.Serializer.JSONSerializer do
  @moduledoc """
  Serializes and deserializes a block, including for transactions and receipts
  We push blocks to IPFS blockchain in the format of a unix-like file system.
  This helps us serialize and deserialize that format.

  For example:

  ```
  /ipfs/<block_hash>                    # root
  /ipfs/<block_hash>/block              # block data root
  /ipfs/<block_hash>/block/block_number # block number
  /ipfs/<block_hash>/block/...
  /ipfs/<block_hash>/transactions       # transaction root
  /ipfs/<block_hash>/transactions/0     # first transaction
  /ipfs/<block_hash>/transactions/1     # second transaction
  /ipfs/<block_hash>/transactions/...
  /ipfs/<block_hash>/receipts           # receipt root
  /ipfs/<block_hash>/receipts/0         # first receipt
  /ipfs/<block_hash>/receipts/1         # second receipt
  /ipfs/<block_hash>/receipts/...
  /ipfs/<block_hash>/queued_transactions
  /ipfs/<block_hash>/storage            # storage root
  /ipfs/<block_hash>/storage/...        # storage items
  ```

  This serializer always encodes the final result as JSON.
  TODO: Uhh, is this JSON anymore?
  """
  import Daisy.Encoder

  @doc ~S"""
  Serializes a block, including the transactions and receipts. This is
  the canonical way to serialize an entire processed block. This should be
  stored in IPFS.

  ## Examples

      iex> %Daisy.Data.Block{
      ...>   block_number: 5,
      ...>   parent_block_hash: "2",
      ...>   initial_storage: "3",
      ...>   final_storage: "4",
      ...>   transactions: [%Daisy.Data.Transaction{
      ...>     signature: %Daisy.Data.Signature{
      ...>       signature: <<1::512>>,
      ...>       public_key: <<5::512>>
      ...>     },
      ...>     invokation: %Daisy.Data.Invokation{
      ...>       function: "func",
      ...>       args: ["red", "tree"]
      ...>     }
      ...>   }],
      ...>   receipts: [%Daisy.Data.Receipt{
      ...>     status: 0,
      ...>     initial_storage: "1",
      ...>     final_storage: "2",
      ...>     logs: ["log1", "log2"],
      ...>     debug: "debug message"
      ...>   }]
      ...> }
      ...> |> Daisy.Serializer.JSONSerializer.serialize()
      %{
        "block_number" => "5",
        "parent_block_hash" => {:link, "2"},
        "initial_storage" => {:link, "3"},
        "final_storage" => {:link, "4"},
        "transactions" => %{
          "0" => %{
            "signature" => "1111111111111111111111111111111111111111111111111111111111111112",
            "public_key" => "1111111111111111111111111111111111111111111111111111111111111116",
            "function" => "func",
            "args" => ["red","tree"]
          }
        },
        "receipts" => %{
          "0" => %{
            "status" => "0",
            "logs" => ["log1","log2"],
            "initial_storage" => {:link, "1"},
            "final_storage" => {:link, "2"},
            "debug" => "debug message"
          }
        }
      }
  """
  @spec serialize(Daisy.Data.Block.t) :: %{}
  def serialize(block) do
    transaction_map = for {transaction, i} <- block.transactions |> Enum.with_index do
      {"#{i}", serialize_transaction(transaction)}
    end |> Enum.into(%{})

    receipt_map = for {receipt, i} <- block.receipts |> Enum.with_index do
      {"#{i}", serialize_receipt(receipt)}
    end |> Enum.into(%{})

    serialize_block_data(block)
    |> Map.put("transactions", transaction_map)
    |> Map.put("receipts", receipt_map)
  end

  @doc ~S"""
  Deserializes a block, including the transactions and receipts. This is
  the canonical way to deserialize an entire processed block. This should be
  loaded from IPFS.

  ## Examples

      iex> %{
      ...>   "block_number" => "6",
      ...>   "parent_block_hash" => {:link, "2"},
      ...>   "initial_storage" => {:link, "3"},
      ...>   "final_storage" => {:link, "4"},
      ...>   "transactions" => %{
      ...>     "0" => %{
      ...>       "signature" => "1111111111111111111111111111111111111111111111111111111111111112",
      ...>       "public_key" => "1111111111111111111111111111111111111111111111111111111111111116",
      ...>       "function" => "func",
      ...>       "args" => ["red","tree"]
      ...>     }
      ...>   },
      ...>   "receipts" => %{
      ...>     "0" => %{
      ...>       "status" => "0",
      ...>       "logs" => ["log1","log2"],
      ...>       "initial_storage" => {:link, "1"},
      ...>       "final_storage" => {:link, "2"},
      ...>       "debug" => "debug message"
      ...>     }
      ...>   },
      ...> }
      ...> |> Daisy.Serializer.JSONSerializer.deserialize()
      %Daisy.Data.Block{
        block_number: 6,
        parent_block_hash: "2",
        initial_storage: "3",
        final_storage: "4",
        transactions: [%Daisy.Data.Transaction{
          signature: %Daisy.Data.Signature{
            signature: <<1>>,
            public_key: <<5>>
          },
          invokation: %Daisy.Data.Invokation{
            function: "func",
            args: ["red", "tree"]
          },
          owner: nil
        }],
        receipts: [%Daisy.Data.Receipt{
          status: 0,
          initial_storage: "1",
          final_storage: "2",
          logs: ["log1", "log2"],
          debug: "debug message"
        }]
      }
  """
  @spec deserialize(%{}) :: Daisy.Data.Block.t
  def deserialize(values) do
    transactions =
      for {number, value} <- values["transactions"] || %{} do
        {String.to_integer(number), deserialize_transaction(value)}
      end
      |> Enum.sort(fn {i,_}, {j,_} -> i < j end)
      |> Enum.map(fn {_,v} -> v end)

    receipts =
      for {number, value} <- values["receipts"] || %{} do
        {String.to_integer(number), deserialize_receipt(value)}
      end
      |> Enum.sort(fn {i,_}, {j,_} -> i < j end)
      |> Enum.map(fn {_,v} -> v end)

    block_data = deserialize_block_data(values)

    %{ block_data |
      transactions: transactions,
      receipts: receipts
    }
  end

  @doc """
  Serializes a block, except the transactions and the reciepts, which
  are serialized by `serialize_transaction/1` and `serialize_receipt/1`
  respectively.

  ## Examples

      iex> %Daisy.Data.Block{
      ...>   block_number: 10,
      ...>   parent_block_hash: "2",
      ...>   initial_storage: "3",
      ...>   final_storage: "4"
      ...> }
      ...> |> Daisy.Serializer.JSONSerializer.serialize_block_data()
      %{
        "block_number" => "10",
        "parent_block_hash" => {:link, "2"},
        "initial_storage" => {:link, "3"},
        "final_storage" => {:link, "4"},
      }
  """
  @spec serialize_block_data(Daisy.Block.t) :: %{}
  def serialize_block_data(block) do
    %{
      "block_number" => block.block_number |> to_string,
      "parent_block_hash" => {:link, block.parent_block_hash},
      "initial_storage" => {:link, block.initial_storage},
      "final_storage" => {:link, block.final_storage},
    }
  end

  @doc """
  Deserializes a block, except the transactions and the reciepts, which
  are serialized by `deserialize_transaction/1` and `deserialize_receipt/1`
  respectively.

  ## Examples

      iex> %{
      ...>   "block_number" => "55",
      ...>   "parent_block_hash" => {:link, "2"},
      ...>   "initial_storage" => {:link, "3"},
      ...>   "final_storage" => {:link, "4"},
      ...> }
      ...> |> Daisy.Serializer.JSONSerializer.deserialize_block_data()
      Daisy.Data.Block.new(
        block_number: 55,
        parent_block_hash: "2",
        initial_storage: "3",
        final_storage: "4"
      )
  """
  @spec deserialize_block_data(%{}) :: Daisy.Block.t
  def deserialize_block_data(data) do
    Daisy.Data.Block.new(
      block_number: data["block_number"] |> String.to_integer,
      parent_block_hash: get_link!(data["parent_block_hash"]),
      initial_storage: get_link!(data["initial_storage"]),
      final_storage: get_link!(data["final_storage"])
    )
  end

  @doc """
  Serializes a transaction.

  ## Examples

      iex> %Daisy.Data.Transaction{
      ...>   signature: %Daisy.Data.Signature{
      ...>     signature: <<1::512>>,
      ...>     public_key: <<5::512>>
      ...>   },
      ...>   invokation: %Daisy.Data.Invokation{
      ...>     function: "func",
      ...>     args: ["red", "tree"]
      ...>   }
      ...> }
      ...> |> Daisy.Serializer.JSONSerializer.serialize_transaction()
      %{
        "signature" => "1111111111111111111111111111111111111111111111111111111111111112",
        "public_key" => "1111111111111111111111111111111111111111111111111111111111111116",
        "function" => "func",
        "args" => ["red", "tree"],
      }

      iex> %Daisy.Data.Transaction{
      ...>   invokation: %Daisy.Data.Invokation{
      ...>     function: "func",
      ...>     args: ["red", "tree"]
      ...>   },
      ...>   owner: <<1>>,
      ...> }
      ...> |> Daisy.Serializer.JSONSerializer.serialize_transaction()
      %{
        "function" => "func",
        "args" => ["red", "tree"],
        "owner" => "2"
      }
  """
  @spec serialize_transaction(Daisy.Data.Transaction.t) :: %{}
  def serialize_transaction(transaction) do
    base = %{
      "function" => transaction.invokation.function,
      "args" => transaction.invokation.args
    }

    cond do
      transaction.signature ->
        base
          |> Map.put("signature", encode_58(transaction.signature.signature))
          |> Map.put("public_key", encode_58(transaction.signature.public_key))
      transaction.owner ->
        base
          |> Map.put("owner", encode_58(transaction.owner))
    end
  end

  @doc """
  Deserializes a transaction from the serialized (IPFS) version.

  ## Examples

      iex> %{
      ...>   "signature" => "1111111111111111111111111111111111111111111111111111111111111112",
      ...>   "public_key" => "1111111111111111111111111111111111111111111111111111111111111116",
      ...>   "function" => "func",
      ...>   "args" => ["red", "tree"],
      ...> }
      ...> |> Daisy.Serializer.JSONSerializer.deserialize_transaction()
      %Daisy.Data.Transaction{
        signature: %Daisy.Data.Signature{
          signature: <<1>>,
          public_key: <<5>>
        },
        invokation: %Daisy.Data.Invokation{
          function: "func",
          args: ["red", "tree"]
        }
      }
  """
  @spec deserialize_transaction(%{}) :: Daisy.Data.Transaction.t
  def deserialize_transaction(data) do
    Daisy.Data.Transaction.new(
      invokation: Daisy.Data.Invokation.new(
        function: data["function"],
        args: data["args"],
      ),
      signature: Daisy.Data.Signature.new(
        signature: data["signature"] |> maybe_decode_58!() || "",
        public_key: data["public_key"] |> maybe_decode_58!() || "",
      ),
      owner: data["owner"] |> maybe_decode_58!()
    )
  end

  @doc """
  Serializes a receipt.

  ## Examples

      iex> %Daisy.Data.Receipt{
      ...>   status: 0,
      ...>   initial_storage: "1",
      ...>   final_storage: "2",
      ...>   logs: ["log1", "log2"],
      ...>   debug: "debug message"
      ...> }
      ...> |> Daisy.Serializer.JSONSerializer.serialize_receipt()
      %{
        "status" => "0",
        "initial_storage" => {:link, "1"},
        "final_storage" => {:link, "2"},
        "logs" => ["log1", "log2"],
        "debug" => "debug message"
      }
  """
  @spec serialize_receipt(Daisy.Data.Receipt.t) :: %{}
  def serialize_receipt(receipt) do
    %{
      "status" => receipt.status |> to_string,
      "initial_storage" => {:link, receipt.initial_storage},
      "final_storage" => {:link, receipt.final_storage},
      "logs" => receipt.logs,
      "debug" => receipt.debug
    }
  end

  @doc """
  Deserializes a receipt.

  ## Examples

      iex> %{
      ...>   "status" => "0",
      ...>   "initial_storage" => {:link, "2"},
      ...>   "final_storage" => {:link, "3"},
      ...>   "logs" => ["log1", "log2"],
      ...>   "debug" => "debug message"
      ...> }
      ...> |> Daisy.Serializer.JSONSerializer.deserialize_receipt()
      %Daisy.Data.Receipt{
        status: 0,
        initial_storage: "2",
        final_storage: "3",
        logs: ["log1", "log2"],
        debug: "debug message"
      }
  """
  @spec deserialize_receipt(%{}) :: Daisy.Data.Receipt.t
  def deserialize_receipt(data) do
    Daisy.Data.Receipt.new(
      status: data["status"] |> String.to_integer,
      initial_storage: get_link!(data["initial_storage"]),
      final_storage: get_link!(data["final_storage"]),
      logs: data["logs"],
      debug: data["debug"],
    )
  end

  @spec get_link!({:link, String.t} | String.t) :: String.t
  defp get_link!({:link, link}), do: link
  defp get_link!(els), do: raise "expected link, got #{inspect els}"

end