defmodule Hub.Plugins.Zoom.FetchWorkerTest do
  use Hub.DataCase
  use Oban.Testing, repo: Hub.Repo

  alias Hub.Plugins.Zoom.FetchWorker
  alias Hub.Documents.RawDocument

  @sample_vtt File.read!("test/support/fixtures/sample.vtt")

  describe "perform/1" do
    test "stores raw document from VTT content" do
      args = %{
        "meeting_uuid" => "test-meeting-123",
        "topic" => "Client Check-in",
        "host_email" => "austin@tenfore.com",
        "start_time" => "2026-03-30T14:00:00Z",
        "download_url" => "https://fake.zoom.us/transcript",
        "vtt_content" => @sample_vtt
      }

      assert :ok = perform_job(FetchWorker, args)

      doc = Hub.Repo.get_by!(RawDocument, source_id: "test-meeting-123")
      assert doc.source == "zoom"
      assert doc.content =~ "Good morning everyone"
      assert length(doc.segments) == 5
      assert "Igor Kuznetsov" in doc.participants
      assert "Austin Smith" in doc.participants
      assert doc.metadata["topic"] == "Client Check-in"
    end

    test "skips if document already exists" do
      attrs = %{source: "zoom", source_id: "test-meeting-123", content: "existing", segments: [], participants: [], metadata: %{}}
      {:ok, _} = %RawDocument{} |> RawDocument.changeset(attrs) |> Hub.Repo.insert()

      args = %{
        "meeting_uuid" => "test-meeting-123",
        "topic" => "Client Check-in",
        "host_email" => "austin@tenfore.com",
        "start_time" => "2026-03-30T14:00:00Z",
        "download_url" => "https://fake.zoom.us/transcript",
        "vtt_content" => @sample_vtt
      }

      assert :ok = perform_job(FetchWorker, args)
      assert Hub.Repo.aggregate(RawDocument, :count) == 1
    end
  end
end
