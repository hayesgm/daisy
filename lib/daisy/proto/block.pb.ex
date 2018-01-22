defmodule Daisy.Data.Block do
  use Protobufex, syntax: :proto3

  @type t :: %__MODULE__{
    initial_storage: String.t,
    final_storage:   String.t,
    transactions:    [Daisy.Data.Transaction.t],
    receipts:        [Daisy.Data.Receipt.t]
  }
  defstruct [:initial_storage, :final_storage, :transactions, :receipts]

  field :initial_storage, 1, type: :string
  field :final_storage, 2, type: :string
  field :transactions, 3, repeated: true, type: Daisy.Data.Transaction
  field :receipts, 4, repeated: true, type: Daisy.Data.Receipt
end
