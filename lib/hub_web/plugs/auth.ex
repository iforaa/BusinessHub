defmodule HubWeb.Plugs.Auth do
  @moduledoc """
  Reads the current user from the Phoenix session and assigns it to the conn.
  Redirects to /login when `require_auth: true` and no user is present.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(conn, opts) do
    case get_session(conn, "current_user") do
      nil ->
        if opts[:require_auth] do
          conn |> redirect(to: "/login") |> halt()
        else
          assign(conn, :current_user, nil)
        end

      user ->
        assign(conn, :current_user, user)
    end
  end

  def put_user(conn, user), do: put_session(conn, "current_user", user)

  def clear_user(conn) do
    conn
    |> configure_session(drop: true)
    |> assign(:current_user, nil)
  end

  def on_mount(:require_auth, _params, session, socket) do
    case session["current_user"] do
      %{email: _} = user ->
        {:cont, Phoenix.Component.assign(socket, :current_user, user)}

      _ ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}
    end
  end
end
