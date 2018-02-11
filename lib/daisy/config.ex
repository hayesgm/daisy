defmodule Daisy.Config do
  @default_port 2335
  @default_scheme :http

  @spec run_api? :: boolean()
  def run_api? do
    Application.get_env(:daisy, :run_api, false)
  end

  @spec run_leader? :: boolean()
  def run_leader? do
    Application.get_env(:daisy, :run_leader, false)
  end

  @spec run_follower? :: boolean()
  def run_follower? do
    Application.get_env(:daisy, :run_follower, false)
  end

  def get_runner(), do: Application.get_env(:daisy, :runner)
  def get_reader(), do: Application.get_env(:daisy, :reader)
  def get_ipfs_key(), do: Application.get_env(:daisy, :ipfs_key)
  def get_serializer(), do: Application.get_env(:daisy, :serializer)

  @spec get_port :: integer()
  def get_port do
    Application.get_env(:daisy, :api_port, @default_port)
    |> maybe_system_var
    |> as_integer
  end

  @spec get_scheme :: integer()
  def get_scheme do
    Application.get_env(:daisy, :api_scheme, @default_scheme)
    |> maybe_system_var
    |> as_scheme
  end

  @spec maybe_system_var({:system, String.t} | any()) :: String.t | any()
  defp maybe_system_var({:system, var}), do: System.get_env(var)
  defp maybe_system_var(els), do: els

  defp as_integer(val) when is_integer(val), do: val
  defp as_integer(val) when is_binary(val), do: String.to_integer(val)

  defp as_scheme(val) when is_atom(val), do: val
  defp as_scheme("http"), do: :http
  defp as_scheme("https"), do: :https
  defp as_scheme(els), do: raise "Invalid scheme, expected http or https, got `#{inspect els}`"

end