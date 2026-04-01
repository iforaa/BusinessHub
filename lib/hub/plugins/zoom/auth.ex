defmodule Hub.Plugins.Zoom.Auth do
  use GenServer
  require Logger

  @token_url "https://zoom.us/oauth/token"
  @refresh_buffer_ms 5 * 60 * 1000

  # Client API

  def start_link(opts \\ []) do
    config = opts[:config] || zoom_config()
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def get_token do
    GenServer.call(__MODULE__, :get_token)
  end

  def build_auth_header(client_id, client_secret) do
    encoded = Base.encode64("#{client_id}:#{client_secret}")
    "Basic #{encoded}"
  end

  # Server callbacks

  @impl true
  def init(config) do
    state = %{
      config: config,
      token: nil,
      expires_at: nil
    }

    {:ok, state, {:continue, :fetch_token}}
  end

  @impl true
  def handle_continue(:fetch_token, state) do
    case fetch_token(state.config) do
      {:ok, token, expires_in} ->
        schedule_refresh(expires_in)
        {:noreply, %{state | token: token, expires_at: System.monotonic_time(:millisecond) + expires_in * 1000}}

      {:error, reason} ->
        Logger.error("Failed to fetch Zoom token: #{inspect(reason)}. Retrying in 30s.")
        Process.send_after(self(), :refresh_token, 30_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_token, _from, %{token: nil} = state) do
    {:reply, {:error, :no_token}, state}
  end

  def handle_call(:get_token, _from, state) do
    {:reply, {:ok, state.token}, state}
  end

  @impl true
  def handle_info(:refresh_token, state) do
    {:noreply, state, {:continue, :fetch_token}}
  end

  # Token fetch

  def fetch_token(config) do
    auth_header = build_auth_header(config.client_id, config.client_secret)

    case Req.post(@token_url,
      params: [grant_type: "account_credentials", account_id: config.account_id],
      headers: [{"authorization", auth_header}]
    ) do
      {:ok, %{status: 200, body: %{"access_token" => token, "expires_in" => expires_in}}} ->
        Logger.info("Zoom OAuth token fetched successfully, expires in #{expires_in}s")
        {:ok, token, expires_in}

      {:ok, %{status: status, body: body}} ->
        {:error, "Zoom token request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp schedule_refresh(expires_in_seconds) do
    refresh_in = max((expires_in_seconds * 1000) - @refresh_buffer_ms, 10_000)
    Process.send_after(self(), :refresh_token, refresh_in)
  end

  defp zoom_config do
    config = Application.fetch_env!(:hub, :zoom)
    %{
      account_id: config[:account_id],
      client_id: config[:client_id],
      client_secret: config[:client_secret]
    }
  end
end
