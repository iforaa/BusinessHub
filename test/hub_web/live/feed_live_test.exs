defmodule HubWeb.FeedLiveTest do
  use HubWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Hub.Documents.{RawDocument, ProcessedDocument, Signal}

  describe "Feed page" do
    test "renders empty state", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")
      assert html =~ "No transcripts yet"
    end

    test "renders processed documents", %{conn: conn} do
      {:ok, raw_doc} = insert_raw_document()
      {:ok, proc_doc} = insert_processed_document(raw_doc)
      insert_signal(proc_doc, "feature_request", "Apple Pay on kiosks")

      {:ok, view, html} = live(conn, "/")
      assert html =~ "Client Check-in"
      assert html =~ "Apple Pay on kiosks"
      assert html =~ "feature_request"
    end

    test "receives real-time updates via PubSub", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      {:ok, raw_doc} = insert_raw_document(source_id: "realtime-1")
      {:ok, proc_doc} = insert_processed_document(raw_doc, summary: "Real-time test summary")

      Phoenix.PubSub.broadcast(Hub.PubSub, "documents", {:document_processed, proc_doc.id})

      assert render(view) =~ "Real-time test summary"
    end
  end

  defp insert_raw_document(overrides \\ []) do
    %RawDocument{}
    |> RawDocument.changeset(%{
      source: "zoom",
      source_id: overrides[:source_id] || "feed-test-1",
      content: "Igor: Hello",
      segments: [],
      participants: ["Igor Kuznetsov", "Austin Smith"],
      metadata: %{"topic" => "Client Check-in", "start_time" => "2026-03-30T14:00:00Z"}
    })
    |> Hub.Repo.insert()
  end

  defp insert_processed_document(raw_doc, overrides \\ []) do
    %ProcessedDocument{}
    |> ProcessedDocument.changeset(%{
      raw_document_id: raw_doc.id,
      summary: overrides[:summary] || "Discussed client issues.",
      action_items: [],
      model: "claude-sonnet-4-20250514",
      prompt_version: "v1",
      processed_at: DateTime.utc_now()
    })
    |> Hub.Repo.insert()
  end

  defp insert_signal(processed_doc, type, content) do
    %Signal{}
    |> Signal.changeset(%{
      processed_document_id: processed_doc.id,
      type: type,
      content: content,
      speaker: "Austin Smith",
      confidence: 0.9
    })
    |> Hub.Repo.insert()
  end
end
