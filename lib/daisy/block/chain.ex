defmodule Daisy.Block.Chain do
  @moduledoc """
  `Daisy.Block.Chain` verifies that blocks match other blocks and/or belong in
  a block chain. This allows us to know blocks that come for a remote peer are
  valid blocks. This does not verify the signature of the blocks, however.
  """

  # TODO: Add tests
  @spec verify_block_chain(Daisy.Data.Block.t, Daisy.Data.Block.t, identifier(), module()) :: {:ok, Daisy.Data.Block.t} | {:error, any()}
  def verify_block_chain(current_block, final_block, storage_pid, runner) do
    case do_verify_block_chain(current_block, final_block, storage_pid, runner) do
      :ok -> {:ok, final_block}
      {:error, error} -> {:error, error}
    end
  end

  @spec do_verify_block_chain(Daisy.Data.Block.t, Daisy.Data.Block.t, identifier(), module()) :: :ok | {:error, any()}
  defp do_verify_block_chain(current_block, final_block, storage_pid, runner) do
    # Let's verify the given block and walk backwards
    case compare(final_block.block_number, current_block.block_number) do
      :lt ->
        # We cannot verify a block chain that occurs before our given block
        {:error, "final block #{final_block.block_number} less than current block #{current_block.block_number}"}
      :eq ->
        # If reach the current block, we need to full match the blocks themselves
        case compare_blocks(final_block, current_block) do
          :match -> :ok
          {:mismatch, mismatches} -> {:error, "final block differs from current block at #{final_block.block_number}: #{inspect mismatches}"}
        end
      :gt ->
        # Verify this block, and if it is good, walk back and verify its parent
        case verify_block(final_block, storage_pid, runner) do
          :ok ->
            case load_parent_block(final_block, storage_pid) do
              {:ok, parent_block} -> do_verify_block_chain(current_block, parent_block, storage_pid, runner)
              :not_found -> {:error, "parent block not found for #{final_block.parent_block_hash}"}
              {:error, error} -> {:error, error}
            end
          {:error, error} -> {:error, "error verifying block at #{final_block.block_number}: #{inspect error}"}
        end
    end
  end

  @doc """
  Verifies that a given block matches expectation. That is, we start the block
  from its initial state and re-run all transactions. At the end, we verify
  that the block has the final final state as the block as it was passed in.

  TODO: Test
  """
  @spec verify_block(Daisy.Data.Block.t, identifier(), module()) :: :ok | {:error, any()}
  def verify_block(block, storage_pid, runner) do
    # Verification is pretty simple, first we wipe the final stroage and the receipts
    # and then we process the block and verify it matches

    processed_block_result = block
    |> clear_final_state
    |> Daisy.Block.Processor.process_block(storage_pid, runner)

    with {:ok, processed_block} <- processed_block_result do
      case compare_blocks(block, processed_block) do
        :match -> :ok
        {:mismatch, mismatches} -> {:error, "mismatch blocks: #{inspect mismatches}"}
      end
    end
  end

  @doc """
  Compares two blocks, returning whether they match or which keys they
  mismatch on.

  # TODO: Test
  """
  @spec compare_blocks(Daisy.Data.Block.t, Daisy.Data.Block.t) :: :match | {:mismatch, [{atom(), any(), any()}]}
  def compare_blocks(block_a, block_b) do
    mismatches = Enum.reduce(Map.from_struct(block_a), [], fn {k, v1}, mismatches ->
      if (v2 = Map.get(block_b, k)) == v1 do
        mismatches
      else
        [{k, v1, v2} | mismatches]
      end
    end)

    if mismatches == [] do
      :match
    else
      {:mismatch, mismatches}
    end
  end

  @spec clear_final_state(Daisy.Data.Block.t) :: Daisy.Data.Block.t
  defp clear_final_state(block) do
    %{block|final_storage: nil, receipts: []}
  end

  # Helper for comparisons with case statements
  @spec compare(integer(), integer()) :: :gt | :lt | :eq
  defp compare(a, b) when a > b, do: :gt
  defp compare(a, b) when a < b, do: :lt
  defp compare(a, b) when a == b, do: :eq

  # TODO: Test
  defp load_parent_block(block, storage_pid) do
    # TODO: Check if genesis block?
    Daisy.Block.BlockStorage.load_block(block.parent_block_hash, storage_pid)
  end

end