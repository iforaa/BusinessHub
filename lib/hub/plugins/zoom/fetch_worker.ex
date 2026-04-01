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
      with {:ok, vtt_content} <- fetch_vtt(args),
           {:ok, segments} <- Parser.parse_vtt(vtt_content),
           {:ok, raw_doc} <- store_document(args, segments, vtt_content) do
        Logger.info("Stored transcript for meeting #{meeting_uuid} (#{length(segments)} segments)")

        # Enqueue AI processing
        %{raw_document_id: raw_doc.id}
        |> Hub.Pipeline.Processor.new()
        |> Oban.insert!()

        :ok
      else
        {:error, reason} ->
          Logger.error("Failed to fetch transcript for meeting #{meeting_uuid}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp fetch_vtt(%{"vtt_content" => content}) when is_binary(content), do: {:ok, content}
  defp fetch_vtt(%{"download_url" => url}), do: Client.download_transcript(url)

  defp store_document(args, segments, _vtt_content) do
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
