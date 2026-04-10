defmodule Hub.Auth.Google do
  @moduledoc """
  Validates Google ID tokens via the tokeninfo endpoint and enforces
  domain restrictions for TenFore.
  """

  @tokeninfo_url "https://oauth2.googleapis.com/tokeninfo"
  @allowed_domain "@tenfore.golf"

  require Logger

  def validate(credential) when is_binary(credential) do
    with {:ok, payload} <- fetch_tokeninfo(credential),
         :ok <- verify_audience(payload),
         :ok <- verify_email_verified(payload),
         :ok <- verify_domain(payload) do
      {:ok,
       %{
         email: payload["email"],
         name: payload["name"],
         picture: payload["picture"]
       }}
    end
  end

  def validate(_), do: {:error, :invalid_credential}

  defp fetch_tokeninfo(credential) do
    case Req.get(@tokeninfo_url, params: [id_token: credential], receive_timeout: 10_000) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: status}} ->
        Logger.warning("Google tokeninfo returned #{status}")
        {:error, :google_rejected_token}
      {:error, reason} ->
        Logger.error("Google tokeninfo request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp verify_audience(%{"aud" => aud}) do
    if aud == client_id(), do: :ok, else: {:error, :wrong_audience}
  end

  defp verify_audience(_), do: {:error, :missing_audience}

  defp verify_email_verified(%{"email_verified" => "true"}), do: :ok
  defp verify_email_verified(_), do: {:error, :email_not_verified}

  defp verify_domain(%{"email" => email}) when is_binary(email) do
    if String.ends_with?(email, @allowed_domain),
      do: :ok,
      else: {:error, :domain_not_allowed}
  end

  defp verify_domain(_), do: {:error, :missing_email}

  defp client_id do
    Application.fetch_env!(:hub, :google)[:client_id]
  end
end
