defmodule HubWeb.LoginLive do
  use HubWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    client_id = Application.fetch_env!(:hub, :google)[:client_id]
    {:ok, assign(socket, client_id: client_id, page_title: "Sign In")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center px-4" style="background: #f8f7f4;">
      <div class="w-full max-w-sm">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold mb-1" style="color: #2d2a26; letter-spacing: -0.3px;">
            TenFore <span style="color: #7c6f5b; font-weight: 400;">Hub</span>
          </h1>
          <p class="text-sm" style="color: #a09888;">Sign in with your TenFore account</p>
        </div>

        <div class="rounded-xl p-6" style="background: #fff; border: 1px solid #e8e5df;">
          <div id="google-signin" phx-update="ignore" phx-hook="GoogleSignIn" data-client-id={@client_id}></div>

          <p class="text-xs text-center mt-4" style="color: #a09888;">
            Access is restricted to <strong>@tenfore.golf</strong> accounts
          </p>
        </div>
      </div>
    </div>
    """
  end
end
