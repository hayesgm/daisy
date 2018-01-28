defmodule Daisy.API.Router do
  use Plug.Router

  # TODO: Replace
  @reader Kitten.Reader

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/read/:block_hash/:function" do
    conn = fetch_query_params(conn)

    case Daisy.Block.read(Daisy.Storage, block_hash, function, conn.query_params, @reader) do
      {:ok, result} -> send_resp(conn, 200, %{"result" => result} |> Poison.encode!)
      {:error, error} -> send_resp(conn, 500, inspect error)
    end
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end