defmodule Daisy.Data.Block do
  use Protobufex, syntax: :proto3

  @type t :: %__MODULE__{
    block_number:      non_neg_integer,
    parent_block_hash: String.t,
    initial_storage:   String.t,
    final_storage:     String.t,
    transactions:      [Daisy.Data.Transaction.t],
    receipts:          [Daisy.Data.Receipt.t]
  }
  defstruct [:block_number, :parent_block_hash, :initial_storage, :final_storage, :transactions, :receipts]

  field :block_number, 1, type: :uint64
  field :parent_block_hash, 2, type: :string
  field :initial_storage, 3, type: :string
  field :final_storage, 4, type: :string
  field :transactions, 5, repeated: true, type: Daisy.Data.Transaction
  field :receipts, 6, repeated: true, type: Daisy.Data.Receipt
end
