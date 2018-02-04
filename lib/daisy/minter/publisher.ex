defmodule Daisy.Publisher do
  @moduledoc """

  """
  use GenServer
  require Logger

  @type state :: %{
    minter_pid: identifier()
  }

  @interval 10_000
  @mine_timeout 60_000

  def start_link(minter_pid, opts \\ []) do
    name = Keyword.get(opts, :name, nil)

    gen_server_args = if name do
      [name: name]
    else
      []
    end

    GenServer.start_link(__MODULE__, {minter_pid, opts}, gen_server_args)
  end

  @spec init({identifier(), identifier(), keyword()}) :: {:ok, state}
  def init({minter_pid, opts}) do
    mining_interval = Keyword.get(opts, :mining_interval, @interval)

    Logger.info("[#{__MODULE__}] Mining every #{@interval/1000.0} seconds.")

    queue_mining(mining_interval)

    {:ok, %{
      minter_pid: minter_pid
    }}
  end

  ## Server

  def handle_info({:mine_block, interval}, %{minter_pid: minter_pid}=state) do
    Logger.debug(fn -> "[#{__MODULE__}] Requesting new block to publish from minter..." end)

    # First, mine the block
    case Daisy.Minter.mint_current_block(minter_pid) do
      {:ok, final_block_hash} ->
        Logger.info(fn -> "[#{__MODULE__}] Minted block with hash `#{final_block_hash}`, publishing..." end)

        result = Daisy.Persistence.publish(Daisy.Persistence, final_block_hash)

        # TODO: Add links in info
        Logger.info(fn -> "[#{__MODULE__}] Published new block: #{inspect result}" end)
      {:error, error} ->
        Logger.error("[#{__MODULE__}] Error mining block: #{inspect error}")
    end

    # Queue up mining again
    if interval, do: queue_mining(interval)

    {:noreply, state}
  end

  # TODO: Track this ref so we can later stop mining
  defp queue_mining(interval) do
    Process.send_after(self(), {:mine_block, interval}, interval)
  end

  ## Client

  @doc """
  Forces publisher to publish a new block immediately.

  TODO: This should reset the timer
  """
  @spec force_mine_block(identifier()) :: {:ok, Daisy.Block.block_hash} | {:error, any()}
  def force_mine_block(server) do
    GenServer.call(server, {:mine_block, nil}, @mine_timeout)
  end

end