defmodule Daisy.Data.Receipt do
  use Protobufex, syntax: :proto3

  @type t :: %__MODULE__{
    status:          integer,
    initial_storage: String.t,
    final_storage:   String.t,
    logs:            [String.t],
    debug:           String.t
  }
  defstruct [:status, :initial_storage, :final_storage, :logs, :debug]

  field :status, 1, type: Daisy.Data.Receipt.Status, enum: true
  field :initial_storage, 2, type: :string
  field :final_storage, 3, type: :string
  field :logs, 4, repeated: true, type: :string
  field :debug, 5, type: :string
end

defmodule Daisy.Data.Receipt.Status do
  use Protobufex, enum: true, syntax: :proto3

  field :OK, 0
end
