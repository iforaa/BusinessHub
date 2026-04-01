defmodule Hub.Pipeline.ExtractorTest do
  use ExUnit.Case

  alias Hub.Pipeline.Extractor

  describe "build_prompt/2" do
    test "builds extraction prompt with metadata and transcript" do
      metadata = %{
        "topic" => "Client Check-in",
        "start_time" => "2026-03-30T14:00:00Z"
      }
      participants = ["Igor Kuznetsov", "Austin Smith"]
      transcript_text = "Igor Kuznetsov: Hello\nAustin Smith: Hi there"

      prompt = Extractor.build_prompt(transcript_text, participants: participants, metadata: metadata)

      assert prompt =~ "TenFore"
      assert prompt =~ "Client Check-in"
      assert prompt =~ "Igor Kuznetsov, Austin Smith"
      assert prompt =~ "Igor Kuznetsov: Hello"
      assert prompt =~ "feature_request"
    end
  end

  describe "parse_response/1" do
    test "parses valid JSON response" do
      json = ~s({"summary": "Test summary", "action_items": [], "signals": [], "client_names": ["Pine Valley"]})
      assert {:ok, parsed} = Extractor.parse_response(json)
      assert parsed["summary"] == "Test summary"
      assert parsed["client_names"] == ["Pine Valley"]
    end

    test "extracts JSON from markdown code blocks" do
      response = "Here is the extraction:\n```json\n{\"summary\": \"Test\", \"action_items\": [], \"signals\": [], \"client_names\": []}\n```"
      assert {:ok, parsed} = Extractor.parse_response(response)
      assert parsed["summary"] == "Test"
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Extractor.parse_response("not json at all")
    end
  end
end
