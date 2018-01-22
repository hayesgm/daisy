defmodule Daisy.Data.Signature do
  use Protobufex, syntax: :proto3

  @type t :: %__MODULE__{
    signature:  String.t,
    public_key: String.t
  }
  defstruct [:signature, :public_key]

  field :signature, 1, type: :bytes
  field :public_key, 2, type: :bytes
end
