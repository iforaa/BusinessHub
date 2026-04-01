defmodule Hub.Plugins.Zoom.ParserTest do
  use ExUnit.Case

  alias Hub.Plugins.Zoom.Parser

  @fixture_path "test/support/fixtures/sample.vtt"

  describe "parse_vtt/1" do
    test "parses VTT content into structured segments" do
      vtt_content = File.read!(@fixture_path)
      {:ok, segments} = Parser.parse_vtt(vtt_content)

      assert length(segments) == 5

      first = Enum.at(segments, 0)
      assert first.index == 1
      assert first.start_ms == 3_450
      assert first.end_ms == 8_120
      assert first.speaker == "Igor Kuznetsov"
      assert first.text == "Good morning everyone, let's talk about the kiosk update."

      second = Enum.at(segments, 1)
      assert second.speaker == "Austin Smith"
      assert second.start_ms == 8_900
    end

    test "extracts unique participants" do
      vtt_content = File.read!(@fixture_path)
      {:ok, segments} = Parser.parse_vtt(vtt_content)
      participants = Parser.extract_participants(segments)

      assert participants == ["Austin Smith", "Igor Kuznetsov"]
    end

    test "concatenates full text" do
      vtt_content = File.read!(@fixture_path)
      {:ok, segments} = Parser.parse_vtt(vtt_content)
      full_text = Parser.full_text(segments)

      assert full_text =~ "Good morning everyone"
      assert full_text =~ "subcourse switcher is confusing"
    end

    test "returns error for invalid VTT" do
      assert {:error, :invalid_vtt} = Parser.parse_vtt("")
      assert {:error, :invalid_vtt} = Parser.parse_vtt("not a vtt file")
    end
  end
end
