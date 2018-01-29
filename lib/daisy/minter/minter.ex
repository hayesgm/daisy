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

  @interval 5_000

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
  def init({storage_pid, block_hash, runner, reader, opts}) do
    block_result = case block_hash do
      :genesis ->
        Daisy.Block.genesis_block(storage_pid)
      block_hash ->
        Daisy.Block.load_block(storage_pid, block_hash)
    end

    block = case block_result do
      {:ok, block} -> block
      {:error, error} -> raise "Failed to load genesis block #{inspect block_hash}: #{inspect error}"
    end

    if Keyword.get(opts, :mine, false) do
      mining_interval = Keyword.get(opts, :mining_interval, @interval)

      Logger.info("[Miner] Mining every #{@interval/1000.0} seconds.")

      queue_mining(mining_interval)
    end

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

  def handle_cast({:start_mining, interval}, state) do
    queue_mining(interval)

    {:noreply, state}
  end

  def handle_info({:auto_mine_block, interval}, %{block: block, storage_pid: storage_pid, runner: runner}=state) do
    # First, mine the block
    result = case server_mine_block(block, storage_pid, runner) do
      {:ok, final_block_hash, new_block} ->
        Logger.info(fn -> "[Miner] Minted new block with hash `#{final_block_hash}`" end)
        Logger.debug(fn -> "[Miner] New block: #{inspect new_block}" end)

        {:noreply, Map.put(state, :block, new_block)}
      {:error, error} ->
        Logger.error("[Miner] Error mining block: #{inspect error}")

        {:noreply, state}
    end

    # Then queue back up mining
    queue_mining(interval)

    # And return the result
    result
  end

  def handle_call(:mine_block, _from, %{block: block, storage_pid: storage_pid, runner: runner}=state) do
    case server_mine_block(block, storage_pid, runner) do
      {:ok, final_block_hash, new_block} ->
        {:reply, final_block_hash, Map.put(state, :block, new_block)}
      {:error, _error}=error_result ->
        # Don't change state if error
        {:reply, error_result, state}
    end
  end

  # TODO: Track this ref so we can later stop mining
  defp queue_mining(interval) do
    Process.send_after(self(), {:auto_mine_block, interval}, interval)
  end

  @spec server_mine_block(Daisy.Data.Block.t, identifier(), module()) :: {:ok, Daisy.Block.block_hash, Daisy.Data.Block.t} | {:error, any()}
  defp server_mine_block(block, storage_pid, runner) do
    result = with {:ok, _finalized_block, final_block_hash} <- Daisy.Block.process_and_save_block(block, storage_pid, runner) do
      # TODO: Store block remotely

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

  @spec mine_block(identifier()) :: {:ok, Daisy.Block.block_hash} | {:error, any()}
  def mine_block(server) do
    GenServer.call(server, :mine_block)
  end

  @spec add_transaction(identifier(), Daisy.Data.Transaction.t) :: Daisy.Data.Block.t
  def add_transaction(server, transaction) do
    GenServer.call(server, {:add_transaction, transaction})
  end

  @spec read(identifier(), String.t, %{String.t => String.t}) :: {:ok, any()} | {:error, any()}
  def read(server, function, args) do
    GenServer.call(server, {:read, function, args})
  end

  @spec start_mining(identifier(), integer()) :: :ok
  def start_mining(server, interval \\ @interval) do
    GenServer.cast(server, {:start_mining, interval})
  end

end