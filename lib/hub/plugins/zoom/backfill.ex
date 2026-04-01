defmodule Hub.Plugins.Zoom.Backfill do
  alias Hub.Plugins.Zoom.{Auth, Client}

  require Logger

  def run(days_back \\ 30) do
    to_date = Date.utc_today() |> Date.to_iso8601()
    from_date = Date.utc_today() |> Date.add(-days_back) |> Date.to_iso8601()

    Logger.info("Backfilling Zoom transcripts from #{from_date} to #{to_date}")

    with {:ok, users} <- list_users() do
      users
      |> Enum.each(fn user ->
        Logger.info("Fetching recordings for #{user["email"]}")
        backfill_user(user["id"], from_date, to_date)
      end)
    end
  end

  defp list_users do
    with {:ok, token} <- Auth.get_token() do
      case Req.get("https://api.zoom.us/v2/users",
        params: [status: "active", page_size: 300],
        headers: [{"authorization", "Bearer #{token}"}]
      ) do
        {:ok, %{status: 200, body: %{"users" => users}}} -> {:ok, users}
        {:ok, %{status: status, body: body}} -> {:error, "List users failed: #{status} #{inspect(body)}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp backfill_user(user_id, from_date, to_date) do
    case Client.list_user_recordings(user_id, from_date, to_date) do
      {:ok, %{"meetings" => meetings}} ->
        meetings
        |> Enum.each(fn meeting ->
          transcript_files =
            (meeting["recording_files"] || [])
            |> Enum.filter(fn f -> f["file_type"] == "TRANSCRIPT" end)

          Enum.each(transcript_files, fn file ->
            %{
              meeting_uuid: meeting["uuid"],
              topic: meeting["topic"],
              host_email: meeting["host_email"],
              start_time: meeting["start_time"],
              download_url: file["download_url"]
            }
            |> Hub.Plugins.Zoom.FetchWorker.new()
            |> Oban.insert!()
          end)
        end)

        Logger.info("Enqueued #{length(meetings)} meeting(s) for user #{user_id}")

      {:error, reason} ->
        Logger.error("Failed to list recordings for user #{user_id}: #{inspect(reason)}")
    end
  end
end
