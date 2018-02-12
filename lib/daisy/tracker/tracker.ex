defmodule Daisy.Tracker do
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

  def start_link(storage_pid, block_reference, runner, reader, opts \\ []) do
    name = Keyword.get(opts, :name, nil)

    gen_server_args = if name do
      [name: name]
    else
      []
    end

    GenServer.start_link(__MODULE__, {storage_pid, block_reference, runner, reader, opts}, gen_server_args)
  end

  @spec init({identifier(), Daisy.Block.block_reference | :genesis, module(), module(), keyword()}) :: {:ok, state}
  def init({storage_pid, block_reference, runner, reader, _opts}) do
    Logger.info("[#{__MODULE__}] Bootstrapping block reference #{inspect block_reference}")

    block = case Daisy.Block.BlockStorage.load_block_reference(block_reference, storage_pid) do
      {:ok, block} -> block
      {:error, error} -> raise "Failed to load starting block #{inspect block_reference}: #{inspect error}"
    end

    Logger.debug("[#{__MODULE__}] Initial block: #{inspect block}")

    {:ok, %{
      storage_pid: storage_pid,
      block: block,
      runner: runner,
      reader: reader
    }}
  end

  ## Server

  # Adds a transaction to the current block (if we're a runner)
  def handle_call({:add_transaction, transaction}, _from, %{block: block, storage_pid: storage_pid, runner: runner}=state) do
    :ok = verify_runner(runner)

    updated_block = Daisy.Block.Processor.add_transaction(block, storage_pid, transaction)

    {:reply, updated_block, Map.put(state, :block, updated_block)}
  end

  # Returns the most recent block
  # If we're a runner, this block may still be open
  def handle_call(:get_block, _from, %{block: block}=state) do
    {:reply, block, state}
  end

  # Reads data from the current block
  def handle_call({:read, function, args}, _from, %{block: block, storage_pid: storage_pid, reader: reader}=state) do
    # TODO: Fix this once we have a better idea of how incremental transactions work
    result = Daisy.Block.read(storage_pid, block, function, args, reader)

    {:reply, result, state}
  end

  def handle_call({:new_block, new_block}, _from, state=%{block: block, storage_pid: storage_pid, runner: runner}) do
    :ok = verify_reader(runner)

    {success, next_block} = case Daisy.Block.Chain.verify_block_chain(block, new_block, storage_pid, runner) do
      {:ok, new_block} ->

        {true, new_block}
      {:error, error} ->
        Logger.error("#{__MODULE__} Error verifying new block: #{inspect error}")

        {false, block}
    end

    {:reply, success, Map.put(state, :block, next_block)}
  end

  # If we're a runner, we mint the current block and begin processing a new block
  def handle_call(:mint_current_block, _from, %{block: block, storage_pid: storage_pid, runner: runner}=state) do
    :ok = verify_runner(runner)

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
    with {:ok, finalized_block, final_block_hash} <- Daisy.Block.Processor.process_and_save_block(block, storage_pid, runner) do
      Logger.debug("[#{__MODULE__}] Minted block #{inspect finalized_block} (/ipfs/#{final_block_hash})")
      # Finally, start a new block
      with {:ok, new_block} <- Daisy.Block.Builder.new_block(final_block_hash, storage_pid, []) do
        {:ok, final_block_hash, new_block}
      end
    end
  end

  @spec verify_runner(any()) :: :ok | :no_return
  defp verify_runner(nil), do: raise "#{__MODULE__} running in viewer mode"
  defp verify_runner(_), do: :ok

  @spec verify_reader(any()) :: :ok | :no_return
  defp verify_reader(nil), do: :ok
  defp verify_reader(_), do: raise "#{__MODULE__} running in runner mode"

  ## Client

  @doc """
  Returns the block currently being processed. If we're running in runner mode,
  this block may still be open. If we're running in viewer mode, the block will
  come from our given minter.
  """
  @spec get_block(identifier()) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def get_block(server) do
    GenServer.call(server, :get_block)
  end

  @doc """
  Adds a new block to the chain, only if in reader mode.
  """
  @spec new_block(identifier(), Daisy.Data.Block.t) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def new_block(server, block) do
    GenServer.call(server, {:new_block, block})
  end

  @doc """
  Adds a transaction to the current block. This will fail if we're in viewer
  mode.
  """
  @spec add_transaction(identifier(), Daisy.Data.Transaction.t) :: Daisy.Data.Block.t
  def add_transaction(server, transaction) do
    GenServer.call(server, {:add_transaction, transaction})
  end

  @doc """
  Reads data from the current block.
  """
  @spec read(identifier(), String.t, %{String.t => String.t}) :: {:ok, any()} | {:error, any()}
  def read(server, function, args) do
    GenServer.call(server, {:read, function, args})
  end

  @doc """
  For a block in runner mode, this will mint and finalize the current block and
  open a new block.
  """
  def mint_current_block(server) do
    GenServer.call(server, :mint_current_block)
  end

end