defmodule HubWeb.AuthController do
  use HubWeb, :controller

  alias Hub.Auth.Google
  alias HubWeb.Plugs.Auth

  def google(conn, %{"credential" => credential}) do
    case Google.validate(credential) do
      {:ok, user} ->
        conn
        |> Auth.put_user(user)
        |> json(%{success: true, user: user})

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: error_message(reason)})
    end
  end

  def google(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{success: false, error: "Missing credential"})
  end

  def logout(conn, _params) do
    conn
    |> Auth.clear_user()
    |> redirect(to: "/login")
  end

  defp error_message(:domain_not_allowed),
    do: "Access is restricted to @tenfore.golf accounts."

  defp error_message(:email_not_verified), do: "Email is not verified."
  defp error_message(:wrong_audience), do: "Invalid Google client."
  defp error_message(_), do: "Authentication failed."
end
