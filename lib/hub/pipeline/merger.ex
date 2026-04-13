defmodule Hub.Pipeline.Merger do
  alias Hub.Claude

  require Logger

  def merge(results, metadata \\ %{})

  def merge([single], metadata) do
    result = %{
      summary: single["summary"],
      action_items: single["action_items"] || [],
      signals: single["signals"] || [],
      client_names: single["client_names"] || []
    }

    topic = metadata["topic"]
    ai_title = generate_title(topic, result.summary, result.signals)
    Map.put(result, :ai_title, ai_title)
  end

  def merge(results, metadata) do
    raw = %{
      summaries: results |> Enum.map(& &1["summary"]) |> Enum.reject(&is_nil/1),
      action_items: results |> Enum.flat_map(& (&1["action_items"] || [])),
      signals: results |> Enum.flat_map(& (&1["signals"] || [])),
      client_names: results |> Enum.flat_map(& (&1["client_names"] || [])) |> Enum.uniq()
    }

    case consolidate(raw) do
      {:ok, consolidated} ->
        topic = metadata["topic"]
        ai_title = generate_title(topic, consolidated.summary, consolidated.signals)
        Map.put(consolidated, :ai_title, ai_title)

      {:error, _} ->
        %{summary: List.first(raw.summaries) || "", action_items: raw.action_items, signals: raw.signals, client_names: raw.client_names, ai_title: nil}
    end
  end

  defp consolidate(raw) do
    # Truncate signals if too many to fit in context
    signals = if length(raw.signals) > 30, do: Enum.take(raw.signals, 30), else: raw.signals
    raw = %{raw | signals: signals}

    prompt = """
    You have multiple extraction results from different segments of the same meeting transcript. Consolidate them into a single clean result.

    Return JSON (no markdown):
    - summary: 2-3 sentences covering the key decisions and outcomes of the entire meeting
    - action_items: deduplicated list of [{text, person}], merge similar items
    - signals: deduplicated list of [{type, content, speaker, confidence}], merge related signals into one per topic

    Rules:
    - Summary must be concise — 2-3 sentences max, no matter how long the meeting
    - Merge duplicate or overlapping signals about the same issue into ONE signal with a clear description
    - Merge duplicate action items
    - Commitments must name a specific deliverable — drop vague ones like "I'll do it"
    - Each signal's content should be a meaningful standalone description, not a raw quote

    Raw extraction data:
    #{Jason.encode!(raw)}
    """

    case Claude.Client.chat(prompt, system: "You consolidate meeting extraction data. Return only valid JSON.") do
      {:ok, response} -> parse_consolidated(response, raw)
      {:error, reason} ->
        Logger.error("Consolidation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_consolidated(response, raw) do
    case Jason.decode(response) do
      {:ok, parsed} ->
        {:ok, %{
          summary: parsed["summary"] || "",
          action_items: parsed["action_items"] || [],
          signals: parsed["signals"] || [],
          client_names: raw.client_names
        }}

      {:error, _} ->
        case Regex.run(~r/```(?:json)?\s*\n?(.*?)\n?```/s, response) do
          [_, json_str] ->
            case Jason.decode(json_str) do
              {:ok, parsed} ->
                {:ok, %{
                  summary: parsed["summary"] || "",
                  action_items: parsed["action_items"] || [],
                  signals: parsed["signals"] || [],
                  client_names: raw.client_names
                }}
              _ -> {:error, :parse_failed}
            end
          nil -> {:error, :parse_failed}
        end
    end
  end

  @generic_topics ["Zoom Meeting", "My Meeting", "zoom meeting", "my meeting", ""]
  @name_meeting_pattern ~r/^[\w\s]+'s Meeting$/i

  defp generate_title(topic, summary, signals) do
    if generic_topic?(topic) do
      generate_full_title(summary, signals)
    else
      generate_quip(topic, summary, signals)
    end
  end

  defp generic_topic?(nil), do: true
  defp generic_topic?(topic) do
    topic in @generic_topics || Regex.match?(@name_meeting_pattern, topic)
  end

  defp signal_summary(signals) do
    signals |> Enum.map(&to_string(&1["content"] || "")) |> Enum.join("; ")
  end

  defp generate_full_title(summary, signals) do
    signal_text = signal_summary(signals)

    prompt = """
    Generate a short, witty meeting title (under 8 words) that hints at what was actually discussed.

    Summary: #{summary}
    Key signals: #{signal_text}

    Be specific to the content — reference actual topics, decisions, or tensions. Slightly humorous. Return only the title, no quotes.
    """

    case Hub.Claude.Client.chat(prompt, model: "claude-sonnet-4-6", max_tokens: 40) do
      {:ok, title} -> String.trim(title) |> String.trim("\"")
      {:error, _} -> nil
    end
  end

  defp generate_quip(topic, summary, signals) do
    signal_text = signal_summary(signals)

    prompt = """
    Meeting: "#{topic}"
    Summary: #{summary}
    Key signals: #{signal_text}

    Write a short subtitle (8-15 words max) that captures what actually happened. Reference specific topics or decisions. Slightly witty but informative. Return only the subtitle, no quotes.
    """

    case Hub.Claude.Client.chat(prompt, model: "claude-sonnet-4-6", max_tokens: 40) do
      {:ok, quip} -> "#{topic}. #{String.trim(quip) |> String.trim("\"")}"
      {:error, _} -> nil
    end
  end
end
