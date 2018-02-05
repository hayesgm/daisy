defmodule Daisy.Data.Invokation do
  use Protobufex, syntax: :proto3

  @type t :: %__MODULE__{
    function: String.t,
    args:     [String.t]
  }
  defstruct [:function, :args]

  field :function, 1, type: :string
  field :args, 2, repeated: true, type: :string
end

defmodule Daisy.Data.Transaction do
  use Protobufex, syntax: :proto3

  @type t :: %__MODULE__{
    invokation: Daisy.Data.Invokation.t,
    signature:  Daisy.Data.Signature.t,
    owner:      String.t
  }
  defstruct [:invokation, :signature, :owner]

  field :invokation, 1, type: Daisy.Data.Invokation
  field :signature, 2, type: Daisy.Data.Signature
  field :owner, 3, type: :bytes
end
