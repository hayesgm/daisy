defmodule Daisy.Signature do
  @moduledoc """
  Functions for generating or verifying ECDSA digital signatures.
  """

  @type public_key :: binary()
  @type private_key :: binary()
  @type keypair :: {public_key, private_key}

  @algorithm :ecdsa
  @digest :sha256
  @key_type :ecdh
  @ec_curve :secp256k1

  @doc """
  Verifies a daisy signature against a given binary. If it matches, it returns
  the associated public key to the signature.

  ## Examples

      iex> signature = Daisy.Signature.sign("test", Daisy.SignatureTest.test_keypair())
      iex> Daisy.Signature.verify_signature("test", signature)
      {:ok, Daisy.SignatureTest.test_public_key()}

      iex> signature = Daisy.Signature.sign("test", Daisy.SignatureTest.test_keypair())
      iex> Daisy.Signature.verify_signature("wrong", signature)
      {:error, :invalid_signature}
  """
  @spec verify_signature(binary(), Daisy.Data.Signature.t) :: {:ok, public_key} | {:error, :invalid_signature}
  def verify_signature(data, signature) do
    if :crypto.verify(@algorithm, @digest, data, signature.signature, [signature.public_key, @ec_curve]) do
      {:ok, signature.public_key}
    else
      {:error, :invalid_signature}
    end
  end

  @doc """
  Signs a binary with given public / private keypair, generating a
  `Daisy.Data.Signature.t`.

  ## Examples

      iex> signature = Daisy.Signature.sign("test", Daisy.SignatureTest.test_keypair())
      iex> signature.public_key
      Daisy.SignatureTest.test_public_key()
  """
  @spec sign(binary(), keypair) :: Daisy.Data.Signature.t
  def sign(data, {public_key, private_key}) do
    signature = :crypto.sign(@algorithm, @digest, data, [private_key, @ec_curve])

    Daisy.Data.Signature.new(
      signature: signature,
      public_key: public_key
    )
  end

  @doc """
  Generates a new public / private keypair for use with Daisy.

  ## Examples

      iex> {public_key, private_key} = Daisy.Signature.new_keypair()
      iex> byte_size(public_key) > byte_size(private_key)
      true
  """
  @spec new_keypair() :: keypair
  def new_keypair() do
    :crypto.generate_key(@key_type, @ec_curve)
  end

end