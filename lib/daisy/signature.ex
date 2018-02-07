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

  @doc """
  Decodes a public key when given in ASN.1 DER form as a 'SubjectPublicKeyInfo'.
  This is the form that is used when `-pubout -outform DER` is passed to
  OpenSSL.

  ## Examples

      iex> "MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE0NvcjVp5ZANisaXWjzKcnXMNVbwYU7Fa6ua0Nt+LNM7Lp8pOBy6kny6wvMvdwz4q0lQPn5y2VJlHCH7ILABOWQ=="
      ...>   |> Base.decode64!
      ...>   |> Daisy.Signature.decode_der_public_key()
      {:ok,
        <<4, 208, 219, 220, 141, 90, 121, 100, 3, 98, 177, 165, 214, 143,
          50, 156, 157, 115, 13, 85, 188, 24, 83, 177, 90, 234, 230, 180,
          54, 223, 139, 52, 206, 203, 167, 202, 78, 7, 46, 164, 159, 46,
          176, 188, 203, 221, 195, 62, 42, 210, 84, 15, 159, 156, 182, 84,
          153, 71, 8, 126, 200, 44, 0, 78, 89>>}
  """
  @spec decode_der_public_key(binary()) :: {:ok, public_key} | {:error, any()}
  def decode_der_public_key(der_public_key) do
    case :public_key.der_decode(:'SubjectPublicKeyInfo', der_public_key) do
       {:'SubjectPublicKeyInfo', _, public_key} -> {:ok, public_key}
       els -> {:error, "Invalid public key: #{inspect els}"}
    end
  end

end