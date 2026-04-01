defmodule Hub.Pipeline.ChunkerTest do
  use ExUnit.Case

  alias Hub.Pipeline.Chunker

  describe "chunk/2" do
    test "returns single chunk for short transcripts" do
      segments = for i <- 1..10 do
        %{"index" => i, "start_ms" => (i - 1) * 60_000, "end_ms" => i * 60_000,
          "speaker" => "Speaker A", "text" => "Segment #{i} content."}
      end

      chunks = Chunker.chunk(segments, max_duration_ms: 15 * 60_000)
      assert length(chunks) == 1
      assert length(hd(chunks)) == 10
    end

    test "splits long transcripts into chunks at speaker boundaries" do
      segments = for i <- 1..30 do
        speaker = if rem(i, 2) == 0, do: "Speaker A", else: "Speaker B"
        %{"index" => i, "start_ms" => (i - 1) * 120_000, "end_ms" => i * 120_000,
          "speaker" => speaker, "text" => "Segment #{i} content."}
      end

      chunks = Chunker.chunk(segments, max_duration_ms: 15 * 60_000)
      assert length(chunks) >= 3
      assert length(chunks) <= 5

      all_indices = chunks |> List.flatten() |> Enum.map(& &1["index"]) |> Enum.sort()
      assert all_indices == Enum.to_list(1..30)
    end

    test "returns empty list for empty segments" do
      assert Chunker.chunk([], max_duration_ms: 15 * 60_000) == []
    end
  end
end
