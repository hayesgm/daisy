defmodule Daisy.Data.Transaction do
  use Protobufex, syntax: :proto3

  @type t :: %__MODULE__{
    function: String.t,
    args:     [String.t]
  }
  defstruct [:function, :args]

  field :function, 1, type: :string
  field :args, 2, repeated: true, type: :string
end
