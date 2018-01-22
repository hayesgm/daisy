defmodule Daisy.Data.Block do
  use Protobufex, syntax: :proto3

  @type t :: %__MODULE__{
    previous_block_hash: String.t,
    initial_storage:     String.t,
    final_storage:       String.t,
    transactions:        [Daisy.Data.Transaction.t],
    receipts:            [Daisy.Data.Receipt.t]
  }
  defstruct [:previous_block_hash, :initial_storage, :final_storage, :transactions, :receipts]

  field :previous_block_hash, 1, type: :string
  field :initial_storage, 2, type: :string
  field :final_storage, 3, type: :string
  field :transactions, 4, repeated: true, type: Daisy.Data.Transaction
  field :receipts, 5, repeated: true, type: Daisy.Data.Receipt
end
