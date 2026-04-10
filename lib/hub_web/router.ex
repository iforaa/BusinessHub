defmodule HubWeb.Router do
  use HubWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HubWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :require_auth do
    plug HubWeb.Plugs.Auth, require_auth: true
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  scope "/", HubWeb do
    pipe_through :browser

    live "/login", LoginLive
    get "/logout", AuthController, :logout
  end

  scope "/auth", HubWeb do
    pipe_through [:api]
    post "/google", AuthController, :google
  end

  scope "/", HubWeb do
    pipe_through [:browser, :require_auth]

    live_session :require_auth, on_mount: {HubWeb.Plugs.Auth, :require_auth} do
      live "/", FeedLive
      live "/people", PeopleLive
      live "/documents/raw/:id", DocumentLive, :raw
      live "/clients/:id", ClientLive
    end
  end

  scope "/webhooks", HubWeb do
    pipe_through :api
    post "/zoom", ZoomWebhookController, :handle
  end

  if Application.compile_env(:hub, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HubWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
