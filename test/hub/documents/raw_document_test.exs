defmodule Hub.Documents.RawDocumentTest do
  use Hub.DataCase

  alias Hub.Documents.RawDocument

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        source: "zoom",
        source_id: "abc-123",
        content: "Full transcript text here",
        segments: [%{"index" => 1, "start_ms" => 0, "end_ms" => 5000, "speaker" => "Igor", "text" => "Hello"}],
        participants: ["Igor Kuznetsov", "Austin Smith"],
        metadata: %{"topic" => "Weekly standup", "duration_minutes" => 30}
      }

      changeset = RawDocument.changeset(%RawDocument{}, attrs)
      assert changeset.valid?
    end

    test "invalid without required fields" do
      changeset = RawDocument.changeset(%RawDocument{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).source
      assert "can't be blank" in errors_on(changeset).source_id
      assert "can't be blank" in errors_on(changeset).content
    end

    test "enforces unique source + source_id" do
      attrs = %{source: "zoom", source_id: "abc-123", content: "text", segments: [], participants: [], metadata: %{}}
      {:ok, _} = %RawDocument{} |> RawDocument.changeset(attrs) |> Hub.Repo.insert()
      {:error, changeset} = %RawDocument{} |> RawDocument.changeset(attrs) |> Hub.Repo.insert()
      assert "has already been taken" in errors_on(changeset).source_id
    end
  end
end
