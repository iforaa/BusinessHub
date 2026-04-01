defmodule Hub.Pipeline.ProcessorTest do
  use Hub.DataCase
  use Oban.Testing, repo: Hub.Repo

  alias Hub.Pipeline.Processor
  alias Hub.Documents.{RawDocument, ProcessedDocument, Signal}

  describe "perform/1 with mocked extractor" do
    test "processes raw document and stores results" do
      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{
          source: "zoom",
          source_id: "test-proc-123",
          content: "Igor: Hello\nAustin: Hi",
          segments: [
            %{"index" => 1, "start_ms" => 0, "end_ms" => 5000, "speaker" => "Igor", "text" => "Hello"},
            %{"index" => 2, "start_ms" => 5000, "end_ms" => 10000, "speaker" => "Austin", "text" => "Hi"}
          ],
          participants: ["Igor", "Austin"],
          metadata: %{"topic" => "Test Meeting", "start_time" => "2026-03-30T14:00:00Z"}
        })
        |> Hub.Repo.insert()

      args = %{"raw_document_id" => raw_doc.id, "test_extraction" => %{
        "summary" => "Quick greeting.",
        "action_items" => [],
        "signals" => [%{"type" => "positive_feedback", "content" => "Friendly greeting", "speaker" => "Austin", "confidence" => 0.5}],
        "client_names" => []
      }}

      assert :ok = perform_job(Processor, args)

      processed = Hub.Repo.get_by!(ProcessedDocument, raw_document_id: raw_doc.id)
      assert processed.summary == "Quick greeting."

      signals = Hub.Repo.all(Signal)
      assert length(signals) == 1
      assert hd(signals).type == "positive_feedback"
    end
  end
end
