defmodule Hub.Pipeline.Chunker do
  @default_max_duration_ms 15 * 60 * 1000

  def chunk([], _opts), do: []

  def chunk(segments, opts \\ []) do
    max_duration = opts[:max_duration_ms] || @default_max_duration_ms
    total_duration = total_duration_ms(segments)

    if total_duration <= max_duration do
      [segments]
    else
      do_chunk(segments, max_duration)
    end
  end

  defp do_chunk(segments, max_duration) do
    segments
    |> Enum.reduce({[], [], nil}, fn seg, {chunks, current_chunk, chunk_start} ->
      seg_start = seg["start_ms"]
      chunk_start = chunk_start || seg_start
      elapsed = seg_start - chunk_start

      if elapsed >= max_duration and current_chunk != [] do
        {[Enum.reverse(current_chunk) | chunks], [seg], seg_start}
      else
        {chunks, [seg | current_chunk], chunk_start}
      end
    end)
    |> then(fn {chunks, current_chunk, _} ->
      case current_chunk do
        [] -> Enum.reverse(chunks)
        _ -> Enum.reverse([Enum.reverse(current_chunk) | chunks])
      end
    end)
  end

  defp total_duration_ms([]), do: 0

  defp total_duration_ms(segments) do
    first = hd(segments)
    last = List.last(segments)
    (last["end_ms"] || 0) - (first["start_ms"] || 0)
  end
end
