defmodule Daisy.Keychain do
  @moduledoc """
  Helper functions for signing things.
  """

  @spec sign_new_transaction(Daisy.Data.Invokation.t, Daisy.Signature.keypair) :: Daisy.Data.Transaction.t
  def sign_new_transaction(invokation, keypair) do
    Daisy.Data.Transaction.new(
      invokation: invokation,
      signature: Daisy.Signature.sign(
        Daisy.Data.Invokation.encode(invokation),
        keypair
      )
    )
  end

end