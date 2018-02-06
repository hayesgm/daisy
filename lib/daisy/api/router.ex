defmodule Daisy.API.Router do
  use Plug.Router

  # TODO: Replace
  @reader Kitten.Reader

  plug Plug.Logger
  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug :match
  plug :dispatch

  get "/read/:function/*args" do
    case Daisy.Minter.read(Daisy.Minter, function, args) do
      {:ok, result} -> send_resp(conn, 200, %{"result" => result} |> Poison.encode!)
      {:error, error} -> send_resp(conn, 500, inspect error)
    end
  end

  get "/prepare/:function/*args" do
    invokation = Daisy.Data.Invokation.new(function: function, args: args)

    send_resp(conn, 200, Daisy.Data.Invokation.encode(invokation) |> Base.encode64)
  end

  post "/run/:function/*args" do
    IO.inspect(["body", conn.body_params])
    invokation = Daisy.Data.Invokation.new(function: function, args: args)
    signature = conn.body_params["signature"] |> Base.decode64!
    public_key = conn.body_params["public_key"] |> Base.decode64!

    IO.inspect(["Invokation", invokation, "signature", signature], limit: :infinity)

    transaction = Daisy.Data.Transaction.new(
      invokation: invokation,
      signature: Daisy.Data.Signature.new(
        signature: signature,
        public_key: public_key
      )
    )

    IO.inspect(["Transaction", transaction])

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