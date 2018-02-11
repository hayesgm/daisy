defmodule Daisy.Tracker.Follower do
  @moduledoc """
  Pulls and verifies blocks from our fearless leader
  """

  use GenServer
  require Logger

  @type state :: %{
    tracker_pid: identifier()
  }

  @interval 10_000
  @resolve_timeout 60_000

  def start_link(tracker_pid, storage_pid, opts \\ []) do
    name = Keyword.get(opts, :name, nil)

    gen_server_args = if name do
      [name: name]
    else
      []
    end

    GenServer.start_link(__MODULE__, {tracker_pid, storage_pid, opts}, gen_server_args)
  end

  @spec init({identifier(), String.t, keyword()}) :: {:ok, state}
  def init({tracker_pid, storage_pid, opts}) do
    pulling_interval = Keyword.get(opts, :pulling_interval, @interval)

    Logger.info("[#{__MODULE__}] Pulling every #{@interval/1000.0} seconds.")

    queue_pulling(pulling_interval)

    {:ok, %{
      tracker_pid: tracker_pid,
      storage_pid: storage_pid
    }}
  end

  ## Server

  def handle_info({:pull_block, interval}, %{tracker_pid: tracker_pid, storage_pid: storage_pid}=state) do
    Logger.debug(fn -> "[#{__MODULE__}] Pulling block from leader..." end)

    # First, load current block from leader
    case Daisy.Persistence.resolve(Daisy.Persistence) do
      {:ok, block_hash} ->
        # Good, we have a block hash, next load it up
        case Daisy.Block.BlockStorage.load_block(block_hash, storage_pid) do
          {:ok, block} ->
            if Daisy.Tracker.new_block(tracker_pid, block) do
              Logger.info("#{__MODULE__} Loaded new block #{block_hash}...")
              Logger.debug("#{__MODULE__} New block: #{inspect block}")
            else
              Logger.error("[#{__MODULE__}] Failed to load new block #{block_hash}")
            end

          {:error, error} ->
            Logger.error("[#{__MODULE__}] Error loading block #{block_hash}: #{inspect error}")
        end

      {:error, error} ->
        Logger.error("[#{__MODULE__}] Error pulling block: #{inspect error}")
    end

    # Queue up pulling again no matter what happened
    if interval, do: queue_pulling(interval)

    {:noreply, state}
  end

  # TODO: Track this ref so we can later stop pulling
  defp queue_pulling(interval) do
    Process.send_after(self(), {:pull_block, interval}, interval)
  end

  ## Client

  @doc """
  Forces publisher to publish a new block immediately.

  TODO: This should reset the timer
  """
  @spec force_pull_block(identifier()) :: {:ok, Daisy.Block.block_hash} | {:error, any()}
  def force_pull_block(server) do
    GenServer.call(server, {:pull_block, nil}, @resolve_timeout)
  end

end