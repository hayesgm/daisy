defmodule Daisy.Examples.Test do
  @moduledoc """
  Test is a very simple Daisy VM.
  """

  defmodule Reader do
    @behaviour Daisy.Reader

    @spec read(String.t, %{String.t => String.t}, identifier(), Daisy.Storage.root_hash) :: {:ok, any()} | {:erorr, any()}
    def read("result", %{}, storage_pid, storage) do
      case Daisy.Storage.get(storage_pid, storage, "result") do
        {:ok, "result=" <> result} -> {:ok, result |> String.to_integer}
        :not_found -> {:error, :not_found}
        els -> els
      end
    end

    def read("simple", %{"input" => number}, _storage_pid, _storage) do
      {:ok, String.to_integer(number) + 5}
    end
  end

  defmodule Runner do
    @behaviour Daisy.Runner

    @callback run_transaction(Daisy.Data.Invokation.t, identifier(), Daisy.Storage.root_hash, binary()) :: {:ok, Daisy.Runner.transaction_result} | {:error, any()}
    def run_transaction(%Daisy.Data.Invokation{function: "test", args: [a_str, b_str]}, storage_pid, initial_storage, _owner) do
      # Store result
      a = String.to_integer(a_str)
      b = String.to_integer(b_str)

      result = a + b

      {:ok, storage_1} = Daisy.Storage.put(
        storage_pid,
        initial_storage,
        "result",
        "result=#{result}"
      )

      {:ok, %{
        final_storage: storage_1,
        logs: [
          "Added #{a} and #{b} to get #{result}"
        ],
        debug: inspect [a, b, result]
      }}
    end
  end
end