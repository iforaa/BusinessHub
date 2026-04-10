defmodule Hub.Cache do
  use GenServer

  @table :hub_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, value}
        else
          :ets.delete(@table, key)
          :miss
        end
      [] -> :miss
    end
  end

  def put(key, value, ttl_ms \\ 300_000) do
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@table, {key, value, expires_at})
    value
  end

  def invalidate(key) do
    :ets.delete(@table, key)
    :ok
  end

  def invalidate_prefix(prefix) do
    :ets.foldl(fn {key, _, _}, acc ->
      if is_binary(key) and String.starts_with?(key, prefix), do: :ets.delete(@table, key)
      acc
    end, :ok, @table)
  end

  # GenServer

  @impl true
  def init(_) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end
end
