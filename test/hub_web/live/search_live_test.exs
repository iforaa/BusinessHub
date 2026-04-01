defmodule HubWeb.SearchLiveTest do
  use HubWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Hub.Documents.{RawDocument, ProcessedDocument, Signal}

  describe "Search page" do
    test "renders search form", %{conn: conn} do
      {:ok, view, html} = live(conn, "/search")
      assert html =~ "Search"
      assert has_element?(view, "input[name=\"q\"]")
    end

    test "returns matching results", %{conn: conn} do
      {:ok, raw_doc} =
        %RawDocument{}
        |> RawDocument.changeset(%{
          source: "zoom", source_id: "search-1", content: "Discussion about Apple Pay integration",
          segments: [], participants: ["Igor"], metadata: %{"topic" => "Kiosk Review"}
        })
        |> Hub.Repo.insert()

      {:ok, proc_doc} =
        %ProcessedDocument{}
        |> ProcessedDocument.changeset(%{
          raw_document_id: raw_doc.id, summary: "Discussed Apple Pay for kiosks.",
          action_items: [], model: "claude-sonnet-4-20250514", prompt_version: "v1", processed_at: DateTime.utc_now()
        })
        |> Hub.Repo.insert()

      {:ok, view, _html} = live(conn, "/search")
      view |> form("form", %{q: "Apple Pay"}) |> render_submit()

      assert render(view) =~ "Apple Pay"
      assert render(view) =~ "Kiosk Review"
    end

    test "shows no results message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      view |> form("form", %{q: "nonexistent query xyz"}) |> render_submit()

      assert render(view) =~ "No results"
    end
  end
end
