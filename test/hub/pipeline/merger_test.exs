defmodule Hub.Pipeline.MergerTest do
  use ExUnit.Case

  alias Hub.Pipeline.Merger

  describe "merge/1" do
    test "merges multiple chunk results" do
      results = [
        %{
          "summary" => "Discussed kiosk issues.",
          "action_items" => [%{"text" => "Fix Apple Pay", "assignee" => "Igor"}],
          "signals" => [%{"type" => "feature_request", "content" => "Apple Pay on kiosks", "speaker" => "Austin", "confidence" => 0.9}],
          "client_names" => ["Sawyer Creek"]
        },
        %{
          "summary" => "Reviewed subcourse switcher feedback.",
          "action_items" => [%{"text" => "Simplify switcher", "assignee" => "Igor"}],
          "signals" => [%{"type" => "bug_report", "content" => "Subcourse switcher is confusing", "speaker" => "Austin", "confidence" => 0.8}],
          "client_names" => ["Pine Valley", "Sawyer Creek"]
        }
      ]

      merged = Merger.merge(results)

      assert merged.summary =~ "kiosk"
      assert merged.summary =~ "subcourse"
      assert length(merged.action_items) == 2
      assert length(merged.signals) == 2
      assert "Sawyer Creek" in merged.client_names
      assert "Pine Valley" in merged.client_names
    end

    test "returns single result unwrapped" do
      result = %{
        "summary" => "Short meeting.",
        "action_items" => [],
        "signals" => [],
        "client_names" => []
      }

      merged = Merger.merge([result])
      assert merged.summary == "Short meeting."
    end
  end
end
