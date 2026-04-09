defmodule Hub.Plugins.Zoom.Client do
  alias Hub.Plugins.Zoom.Auth

  require Logger

  @base_url "https://api.zoom.us/v2"

  def download_transcript(download_url) do
    with {:ok, token} <- Auth.get_token() do
      case Req.get(download_url, headers: [{"authorization", "Bearer #{token}"}], redirect: true) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: 401}} -> retry_with_fresh_token(fn t -> Req.get(download_url, headers: [{"authorization", "Bearer #{t}"}], redirect: true) end)
        {:ok, %{status: status}} -> {:error, "Download failed with status #{status}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def get_meeting_recordings(meeting_id) do
    encoded_id = double_encode_uuid(meeting_id)
    api_get("/meetings/#{encoded_id}/recordings")
  end

  def list_user_recordings(user_id, from_date, to_date) do
    api_get("/users/#{user_id}/recordings", params: [from: from_date, to: to_date])
  end

  defp api_get(path, opts \\ []) do
    with {:ok, token} <- Auth.get_token() do
      params = Keyword.get(opts, :params, [])

      case Req.get("#{@base_url}#{path}", params: params, headers: [{"authorization", "Bearer #{token}"}]) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: 401}} -> retry_with_fresh_token(fn t -> Req.get("#{@base_url}#{path}", params: params, headers: [{"authorization", "Bearer #{t}"}]) end)
        {:ok, %{status: status, body: body}} -> {:error, "API returned #{status}: #{inspect(body)}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp retry_with_fresh_token(request_fn) do
    Logger.info("Zoom API returned 401, refreshing token and retrying")

    case Auth.refresh_token() do
      {:ok, token} ->
        case request_fn.(token) do
          {:ok, %{status: 200, body: body}} -> {:ok, body}
          {:ok, %{status: status, body: body}} -> {:error, "API returned #{status} after refresh: #{inspect(body)}"}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, "Token refresh failed: #{inspect(reason)}"}
    end
  end

  defp double_encode_uuid(uuid) do
    if String.contains?(uuid, "/") do
      URI.encode(URI.encode(uuid, &URI.char_unreserved?/1), &URI.char_unreserved?/1)
    else
      uuid
    end
  end
end
