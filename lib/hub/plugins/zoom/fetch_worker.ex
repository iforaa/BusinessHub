defmodule Hub.Plugins.Zoom.FetchWorker do
  use Oban.Worker, queue: :zoom, max_attempts: 3

  alias Hub.Documents.RawDocument
  alias Hub.Plugins.Zoom.{Client, Parser}
  alias Hub.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    meeting_uuid = args["meeting_uuid"]

    if Repo.get_by(RawDocument, source: "zoom", source_id: meeting_uuid) do
      Logger.info("Transcript for meeting #{meeting_uuid} already exists, skipping")
      :ok
    else
      with {:ok, vtt_content} <- fetch_transcript(meeting_uuid, args),
           {:ok, segments} <- Parser.parse_vtt(vtt_content) do
        if segments == [] do
          Logger.info("Transcript for meeting #{meeting_uuid} is empty, will retry next poll")
          :ok
        else
          case store_document(args, segments) do
            {:ok, _raw_doc} ->
              Logger.info("Stored transcript for meeting #{meeting_uuid} (#{length(segments)} segments)")
              :ok
            {:error, reason} ->
              Logger.error("Failed to store transcript for meeting #{meeting_uuid}: #{inspect(reason)}")
              {:error, reason}
          end
        end
      else
        {:error, reason} ->
          Logger.error("Failed to fetch transcript for meeting #{meeting_uuid}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  # Try the stored download URL first, if it fails with 401 get a fresh one
  defp fetch_transcript(_meeting_uuid, %{"vtt_content" => content}) when is_binary(content) do
    {:ok, content}
  end

  defp fetch_transcript(meeting_uuid, %{"download_url" => url}) do
    case Client.download_transcript(url) do
      {:ok, _} = success ->
        success

      {:error, "Download failed with status 401"} ->
        Logger.info("Download URL expired for #{meeting_uuid}, fetching fresh URL")
        fetch_fresh_transcript(meeting_uuid)

      {:error, _} = error ->
        error
    end
  end

  defp fetch_fresh_transcript(meeting_uuid) do
    with {:ok, recordings} <- Client.get_meeting_recordings(meeting_uuid),
         {:ok, url} <- find_transcript_url(recordings) do
      Client.download_transcript(url)
    end
  end

  defp find_transcript_url(%{"recording_files" => files}) do
    case Enum.find(files, &(&1["file_type"] == "TRANSCRIPT")) do
      nil -> {:error, "No transcript file found in recording"}
      file -> {:ok, file["download_url"]}
    end
  end

  defp find_transcript_url(_), do: {:error, "No recording files found"}

  defp store_document(args, segments) do
    participants = Parser.extract_participants(segments)
    full_text = Parser.full_text(segments)

    segments_json = Enum.map(segments, fn seg ->
      %{
        "index" => seg.index,
        "start_ms" => seg.start_ms,
        "end_ms" => seg.end_ms,
        "speaker" => seg.speaker,
        "text" => seg.text
      }
    end)

    attrs = %{
      source: "zoom",
      source_id: args["meeting_uuid"],
      content: full_text,
      segments: segments_json,
      participants: participants,
      metadata: %{
        "topic" => args["topic"],
        "host_email" => args["host_email"],
        "start_time" => args["start_time"],
        "download_url" => args["download_url"]
      },
      ingested_at: DateTime.utc_now()
    }

    %RawDocument{}
    |> RawDocument.changeset(attrs)
    |> Repo.insert()
  end
end
