defmodule Daisy.Minter do
  @moduledoc """

  """
  use GenServer
  require Logger

  @type state :: %{
    storage_pid: identifier(),
    block: Daisy.Data.Block.t,
    runner: module(),
    reader: module()
  }

  def start_link(storage_pid, block_hash, runner, reader, opts \\ []) do
    name = Keyword.get(opts, :name, nil)

    gen_server_args = if name do
      [name: name]
    else
      []
    end

    GenServer.start_link(__MODULE__, {storage_pid, block_hash, runner, reader, opts}, gen_server_args)
  end

  @spec init({identifier(), Daisy.Block.block_hash | :genesis, module(), module(), keyword()}) :: {:ok, state}
  def init({storage_pid, block_hash, runner, reader, _opts}) do
    block_result = case block_hash do
      :resolve ->
        Logger.debug("[#{__MODULE__}] Looking up for stored block hash in IPNS...")

        case Daisy.Persistence.resolve(Daisy.Persistence) do
          :not_found ->
            Logger.debug("[#{__MODULE__}] No block found, starting new genesis block")

            Daisy.Block.genesis_block(storage_pid)
          {:ok, block_hash} ->
            Logger.debug("[#{__MODULE__}] Loading block #{block_hash}")

            Daisy.Block.load_block(storage_pid, block_hash)
          {:error, error} -> raise "[#{__MODULE__}] Error resolving block hash: #{inspect error}"
        end
      :genesis ->
        Logger.debug("[#{__MODULE__}] Loading genesis block, as requested.")

        Daisy.Block.genesis_block(storage_pid)
      block_hash ->
        Logger.debug("[#{__MODULE__}] Loading block #{block_hash}, as requested.")

        Daisy.Block.load_block(storage_pid, block_hash)
    end

    block = case block_result do
      {:ok, block} -> block
      {:error, error} -> raise "Failed to load starting block #{inspect block_hash}: #{inspect error}"
    end

    # Logger.info("[#{__MODULE__}] Starting with block hash: #{}")
    Logger.debug("[#{__MODULE__}] Starting block: #{inspect block}")

    {:ok, %{
      storage_pid: storage_pid,
      block: block,
      runner: runner,
      reader: reader
    }}
  end

  ## Server

  def handle_call({:add_transaction, transaction}, _from, %{block: block, storage_pid: storage_pid}=state) do
    updated_block = Daisy.Block.add_transaction(block, storage_pid, transaction)

    {:reply, updated_block, Map.put(state, :block, updated_block)}
  end

  def handle_call(:get_block, _from, %{block: block}=state) do
    {:reply, block, state}
  end

  def handle_call({:read, function, args}, _from, %{block: block, storage_pid: storage_pid, reader: reader}=state) do
    # TODO: Fix this once we have a better idea of how incremental transactions work
    result = Daisy.Block.read(storage_pid, block, function, args, reader)

    {:reply, result, state}
  end

  def handle_call(:mint_current_block, _from, %{block: block, storage_pid: storage_pid, runner: runner}=state) do
    case server_mine_block(block, storage_pid, runner) do
      {:ok, final_block_hash, new_block} ->
        {:reply, {:ok, final_block_hash}, Map.put(state, :block, new_block)}
      {:error, _error}=error_result ->
        # Don't change state if error
        {:reply, error_result, state}
    end
  end

  @spec server_mine_block(Daisy.Data.Block.t, identifier(), module()) :: {:ok, Daisy.Block.block_hash, Daisy.Data.Block.t} | {:error, any()}
  defp server_mine_block(block, storage_pid, runner) do
    # First, finalize the block
    with {:ok, _finalized_block, final_block_hash} <- Daisy.Block.process_and_save_block(block, storage_pid, runner) do
      # Finally, start a new block
      with {:ok, new_block} <- Daisy.Block.new_block(final_block_hash, storage_pid, []) do
        {:ok, final_block_hash, new_block}
      end
    end
  end

  ## Client

  @spec get_block(identifier()) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def get_block(server) do
    GenServer.call(server, :get_block)
  end

  @spec add_transaction(identifier(), Daisy.Data.Transaction.t) :: Daisy.Data.Block.t
  def add_transaction(server, transaction) do
    GenServer.call(server, {:add_transaction, transaction})
  end

  @spec read(identifier(), String.t, %{String.t => String.t}) :: {:ok, any()} | {:error, any()}
  def read(server, function, args) do
    GenServer.call(server, {:read, function, args})
  end

  def mint_current_block(server) do
    GenServer.call(server, :mint_current_block)
  end

end