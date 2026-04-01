defmodule Hub.Plugins.Zoom.Client do
  alias Hub.Plugins.Zoom.Auth

  @base_url "https://api.zoom.us/v2"

  def download_transcript(download_url) do
    with {:ok, token} <- Auth.get_token() do
      case Req.get(download_url, headers: [{"authorization", "Bearer #{token}"}], redirect: true) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: status}} -> {:error, "Download failed with status #{status}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def get_meeting_recordings(meeting_id) do
    with {:ok, token} <- Auth.get_token() do
      encoded_id = double_encode_uuid(meeting_id)

      case Req.get("#{@base_url}/meetings/#{encoded_id}/recordings",
        headers: [{"authorization", "Bearer #{token}"}]
      ) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: status, body: body}} -> {:error, "API returned #{status}: #{inspect(body)}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def list_user_recordings(user_id, from_date, to_date) do
    with {:ok, token} <- Auth.get_token() do
      case Req.get("#{@base_url}/users/#{user_id}/recordings",
        params: [from: from_date, to: to_date],
        headers: [{"authorization", "Bearer #{token}"}]
      ) do
        {:ok, %{status: 200, body: body}} -> {:ok, body}
        {:ok, %{status: status, body: body}} -> {:error, "API returned #{status}: #{inspect(body)}"}
        {:error, reason} -> {:error, reason}
      end
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
