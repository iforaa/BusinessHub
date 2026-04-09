defmodule Hub.Repo do
  use Ecto.Repo,
    otp_app: :hub,
    adapter: Ecto.Adapters.Postgres

  def init(_type, config) do
    {:ok, Keyword.put(config, :types, Hub.PostgrexTypes)}
  end
end
