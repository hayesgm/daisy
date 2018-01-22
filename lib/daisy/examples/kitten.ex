defmodule Kitten do
  @moduledoc """
  Kitten is an example Daisy library. This emulates a simple crypto-kitty
  like world.
  """

  defmodule Data do

    defmodule Kitten do
      defstruct [:uuid, :name]

      @type t :: %__MODULE__{
        uuid: String.t,
        name: String.t
      }

      @spec deserialize(String.t) :: t
      def deserialize(kitten_json) do
        kitten_data = Poison.decode!(kitten_json)

        %__MODULE__{
          uuid: kitten_data["uuid"],
          name: kitten_data["name"]
        }
      end

      @spec serialize(t) :: String.t
      def serialize(kitten) do
        %{
          "uuid" => kitten.uuid,
          "name" => kitten.name
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
      def add_new(orphan, uuid) do
        orphan
        |> Kernel.++([uuid])
      end
    end
  end

  defmodule Reader do
    @behaviour Daisy.Reader

    @spec read(identifier(), String.t, String.t, [String.t]) :: {:ok, any()} | {:erorr, any()}
    def read(storage_pid, storage, "orphans", []) do
      with {:ok, orphan_json} <- Daisy.Storage.get(storage_pid, storage, "orphans") do
        {:ok, Data.Orphan.deserialize(orphan_json)}
      end
    end

    def read(storage_pid, storage, "kitten", [uuid]) do
      with {:ok, kitten_json} <- Daisy.Storage.get(storage_pid, storage, "/kitten/#{uuid}") do
        {:ok, Data.Kitten.deserialize(kitten_json)}
      end
    end
  end

  defmodule Runner do
    @behaviour Daisy.Runner

    @first_names ["mittens", "thomas", "frederick", "bubba"]
    @titles ["the cool", "the wise", "the timid", "the adorable"]

    @callback run_transaction(Daisy.Data.Invokation.t, identifier(), Daisy.Storage.root_hash, binary()) :: {:ok, Daisy.Runner.transaction_result} | {:error, any()}
    def run_transaction(%Daisy.Data.Invokation{function: "spawn", args: [_cooldown]}, storage_pid, initial_storage, owner) do
      # Generate a new random identifier and name
      first_name = @first_names |> Enum.random
      title = @titles |> Enum.random

      kitten = %Data.Kitten{
        uuid: UUID.uuid4(),
        name: "#{first_name} #{title}"
      }

      # Add kitten to storage
      {:ok, storage_with_kitten} = Daisy.Storage.put_new(
        storage_pid,
        initial_storage,
        "/kittens/#{kitten.uuid}",
        kitten |> Data.Kitten.serialize)

      # Add new kitten to list of orphans
      # TODO: default is... default, not default running function, possibly change behaviour?
      {:ok, storage_with_kitten_as_orphan} = Daisy.Storage.update(storage_pid, storage_with_kitten, "/orphans", fn orphan_json ->
        orphan_json
        |> Data.Orphan.deserialize
        |> Data.Orphan.add_new(kitten.uuid)
        |> Data.Orphan.serialize
      end, default: "", run_update_fn_on_default: true)

      {:ok, %{
        final_storage: storage_with_kitten_as_orphan,
        logs: [
          "Added new kitten #{kitten.uuid} from owner #{inspect owner}"
        ],
        debug: inspect kitten
      }}
    end
  end
end