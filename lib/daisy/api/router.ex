defmodule Daisy.API.Router do
  use Plug.Router

  # TODO: Replace
  @reader Kitten.Reader

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/read/:function/*args" do
    case Daisy.Minter.read(Daisy.Minter, function, args) do
      {:ok, result} -> send_resp(conn, 200, %{"result" => result} |> Poison.encode!)
      {:error, error} -> send_resp(conn, 500, inspect error)
    end
  end

  get "/run/:function/*args" do
    invokation = Daisy.Data.Invokation.new(function: function, args: args)
    keypair = Daisy.Signature.new_keypair()
    transaction = Daisy.Keychain.sign_new_transaction(invokation, keypair)

    _result_transaction = Daisy.Minter.add_transaction(Daisy.Minter, transaction)

    send_resp(conn, 200, %{"result" => "ok"} |> Poison.encode! |> Kernel.<>("\n"))
  end

  get "/read/block/:block_hash/:function/*args" do
    case Daisy.Block.read(Daisy.Storage, block_hash, function, args, @reader) do
      {:ok, result} -> send_resp(conn, 200, %{"result" => result} |> Poison.encode!)
      {:error, error} -> send_resp(conn, 500, inspect error)
    end
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

end