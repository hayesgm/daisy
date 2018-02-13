defmodule Daisy.Examples.Kitten do
  @moduledoc """
  Kitten is an example Daisy library. This emulates a simple crypto-kitty
  like world.
  """
  alias Daisy.Random

  defmodule Data do
    defmodule Kitten do
      defstruct [:id, :name, :owner]

      @type t :: %__MODULE__{
        id: String.t,
        name: String.t,
        owner: String.t | nil
      }

      @spec deserialize(String.t) :: t
      def deserialize(kitten_json) do
        kitten_data = Poison.decode!(kitten_json)

        %__MODULE__{
          id: kitten_data["id"],
          name: kitten_data["name"],
          owner: kitten_data["owner"] |> Daisy.Encoder.maybe_decode_58!,
        }
      end

      @spec serialize(t) :: String.t
      def serialize(kitten) do
        %{
          "id" => kitten.id,
          "name" => kitten.name,
          "owner" => kitten.owner |> Daisy.Encoder.maybe_encode_58,
        } |> Poison.encode!
      end
    end

    defmodule Orphan do
      @type t :: [String.t]

      # Initial state
      @spec deserialize(String.t) :: t
      def deserialize("") do
        []
      end

      def deserialize(orphan) do
        orphan |> Poison.decode!
      end

      @spec serialize(t) :: String.t
      def serialize(orphan) do
        orphan |> Poison.encode!
      end

      @spec add_new(t, String.t) :: t
      def add_new(orphan, id) do
        orphan
        |> Kernel.++([id])
      end

      @spec remove(t, String.t) :: t
      def remove(orphan, id) do
        orphan
        |> Enum.reject(&(&1 == id))
      end
    end
  end

  defmodule Reader do
    @behaviour Daisy.Reader

    @spec read(String.t, [String.t], identifier(), Daisy.Storage.root_hash) :: {:ok, any()} | {:erorr, any()}
    def read("orphans", [], storage_pid, storage) do
      case Daisy.Storage.get(storage_pid, storage, "orphans") do
        {:ok, orphan_json} -> {:ok, Data.Orphan.deserialize(orphan_json)}
        :not_found -> {:ok, []}
        error={:error, _error} -> error
      end
    end

    def read("is_orphan?", [kitten_id], storage_pid, storage) do
      with {:ok, orphans} <- read("orphans", [], storage_pid, storage) do
        {:ok, Enum.member?(orphans, kitten_id)}
      end
    end

    def read("kitten", [kitten_id], storage_pid, storage) do
      with {:ok, kitten_json} <- Daisy.Storage.get(storage_pid, storage, "/kittens/#{kitten_id}") do
        {:ok, Data.Kitten.deserialize(kitten_json)}
      end
    end
  end

  defmodule Runner do
    @behaviour Daisy.Runner

    @first_names ["mittens", "thomas", "frederick", "bubba"]
    @titles ["the cool", "the wise", "the timid", "the adorable"]

    @callback run_transaction(Daisy.Data.Invokation.t, identifier(), Daisy.Storage.root_hash, integer(), binary()) :: {:ok, Daisy.Runner.transaction_result} | {:error, any()}
    def run_transaction(%Daisy.Data.Invokation{function: "spawn", args: [cooldown]}, storage_pid, initial_storage, block_number, owner) do
      # Generate a new pseudo-random identifier and name
      rand = Random.init(block_number)
      {rand, first_name} = Random.random_el(rand, @first_names)
      {rand, title} = Random.random_el(rand, @titles)
      {_rand, kitten_id} = Random.unique_id(rand)

      kitten = %Data.Kitten{
        id: kitten_id,
        name: "#{first_name} #{title}"
      }

      # Add kitten to storage
      {:ok, storage_with_kitten} = Daisy.Storage.put_new(
        storage_pid,
        initial_storage,
        "/kittens/#{kitten.id}",
        kitten |> Data.Kitten.serialize)

      # Add new kitten to list of orphans
      # TODO: default is... default, not default running function, possibly change behaviour?
      {:ok, storage_with_kitten_as_orphan} = Daisy.Storage.update(storage_pid, storage_with_kitten, "/orphans", fn orphan_json ->
        orphan_json
        |> Data.Orphan.deserialize
        |> Data.Orphan.add_new(kitten.id)
        |> Data.Orphan.serialize
      end, default: "", run_update_fn_on_default: true)

      # Recursive call spawn after a cooldown period
      {:ok, storage_with_queued_transaction} = Daisy.TransactionQueue.queue(
        storage_pid,
        storage_with_kitten_as_orphan,
        block_number + ( cooldown |> String.to_integer ),
        owner,
        Daisy.Data.Invokation.new(
          function: "spawn",
          args: [cooldown]
        )
      )

      {:ok, %{
        final_storage: storage_with_queued_transaction,
        logs: [
          "Added new kitten #{kitten.id} from owner #{inspect owner}"
        ],
        debug: inspect kitten
      }}
    end

    def run_transaction(%Daisy.Data.Invokation{function: "adopt", args: [kitten_id]}, storage_pid, storage_1, _block_number, owner) do
      # First, check to see that the kitten is up for adoption
      case Reader.read("is_orphan?", [kitten_id], storage_pid, storage_1) do
        {:ok, false} ->
          {:ok, %{
            status: :failure,
            logs: ["Kitten #{kitten_id} not up for adoption"]
          }}
        {:error, error} -> {:error, error}
        {:ok, true} ->
          # Remove kitten from orphans
          {:ok, storage_2} = Daisy.Storage.update(storage_pid, storage_1, "/orphans", fn orphan_json ->
            orphan_json
            |> Data.Orphan.deserialize
            |> Data.Orphan.remove(kitten_id)
            |> Data.Orphan.serialize
          end)

          # Add kitten as adopted
          {:ok, storage_3} = Daisy.Storage.update(storage_pid, storage_2, "/kittens/#{kitten_id}", fn kitten_json ->
            kitten_json
            |> Data.Kitten.deserialize
            |> Map.put(:owner, owner)
            |> Data.Kitten.serialize
          end)

          {:ok, %{
            final_storage: storage_3,
            logs: [
              "Owner #{inspect owner} adopted kitten #{kitten_id}"
            ]
          }}
      end
    end
  end
end