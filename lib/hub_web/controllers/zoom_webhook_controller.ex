defmodule HubWeb.ZoomWebhookController do
  use HubWeb, :controller

  require Logger

  def handle(conn, %{"event" => "endpoint.url_validation", "payload" => %{"plainToken" => token}}) do
    secret = zoom_webhook_secret()
    encrypted = :crypto.mac(:hmac, :sha256, secret, token) |> Base.encode16(case: :lower)

    json(conn, %{plainToken: token, encryptedToken: encrypted})
  end

  def handle(conn, %{"event" => "recording.transcript_completed", "payload" => %{"object" => object}}) do
    meeting_uuid = object["uuid"]
    topic = object["topic"] || "Untitled Meeting"
    host_email = object["host_email"]
    start_time = object["start_time"]

    transcript_files =
      (object["recording_files"] || [])
      |> Enum.filter(fn f -> f["file_type"] == "TRANSCRIPT" end)

    case transcript_files do
      [] ->
        Logger.warning("Transcript completed webhook received but no transcript files found for meeting #{meeting_uuid}")
        json(conn, %{status: "ok", message: "no transcript files"})

      files ->
        Enum.each(files, fn file ->
          %{
            meeting_uuid: meeting_uuid,
            topic: topic,
            host_email: host_email,
            start_time: start_time,
            download_url: file["download_url"],
            participants: object["participant_audio_files"] || []
          }
          |> Hub.Plugins.Zoom.FetchWorker.new()
          |> Oban.insert!()
        end)

        Logger.info("Enqueued #{length(files)} transcript fetch job(s) for meeting #{meeting_uuid}")
        json(conn, %{status: "ok"})
    end
  end

  def handle(conn, %{"event" => event}) do
    Logger.debug("Ignoring Zoom webhook event: #{event}")
    conn |> put_status(400) |> json(%{error: "unhandled event"})
  end

  defp zoom_webhook_secret do
    Application.fetch_env!(:hub, :zoom)[:webhook_secret] || ""
  end
end
