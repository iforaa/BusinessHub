defmodule Hub.Plugins.Zoom.Parser do
  defmodule Segment do
    @derive Jason.Encoder
    defstruct [:index, :start_ms, :end_ms, :speaker, :text]

    @type t :: %__MODULE__{
      index: integer(),
      start_ms: integer(),
      end_ms: integer(),
      speaker: String.t(),
      text: String.t()
    }
  end

  @timestamp_pattern ~r/(\d{2}):(\d{2}):(\d{2})\.(\d{3})/

  def parse_vtt(content) when is_binary(content) do
    content = String.trim(content)

    if content == "" or not String.starts_with?(content, "WEBVTT") do
      {:error, :invalid_vtt}
    else
      segments =
        content
        |> String.split(~r/\n\n+/)
        |> Enum.drop(1)
        |> Enum.map(&parse_block/1)
        |> Enum.reject(&is_nil/1)

      {:ok, segments}
    end
  end

  def extract_participants(segments) do
    segments
    |> Enum.map(& &1.speaker)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def full_text(segments) do
    segments
    |> Enum.map(fn seg -> "#{seg.speaker}: #{seg.text}" end)
    |> Enum.join("\n")
  end

  defp parse_block(block) do
    lines = String.split(block, "\n", trim: true)

    case lines do
      [index_str, timestamp_line | text_lines] ->
        with {index, ""} <- Integer.parse(String.trim(index_str)),
             {start_ms, end_ms} <- parse_timestamps(timestamp_line),
             {speaker, text} <- parse_speaker_text(Enum.join(text_lines, " ")) do
          %Segment{
            index: index,
            start_ms: start_ms,
            end_ms: end_ms,
            speaker: speaker,
            text: text
          }
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_timestamps(line) do
    case Regex.scan(@timestamp_pattern, line) do
      [start_match, end_match] ->
        {timestamp_to_ms(start_match), timestamp_to_ms(end_match)}

      _ ->
        nil
    end
  end

  defp timestamp_to_ms([_full, hours, minutes, seconds, milliseconds]) do
    String.to_integer(hours) * 3_600_000 +
      String.to_integer(minutes) * 60_000 +
      String.to_integer(seconds) * 1_000 +
      String.to_integer(milliseconds)
  end

  defp parse_speaker_text(text) do
    case String.split(text, ": ", parts: 2) do
      [speaker, content] -> {speaker, content}
      [content] -> {"Unknown", content}
    end
  end
end
