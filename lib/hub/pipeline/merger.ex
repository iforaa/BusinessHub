defmodule Hub.Pipeline.Merger do
  alias Hub.Claude

  require Logger

  def merge([single]) do
    %{
      summary: single["summary"],
      action_items: single["action_items"] || [],
      signals: single["signals"] || [],
      client_names: single["client_names"] || []
    }
  end

  def merge(results) do
    raw = %{
      summaries: results |> Enum.map(& &1["summary"]) |> Enum.reject(&is_nil/1),
      action_items: results |> Enum.flat_map(& (&1["action_items"] || [])),
      signals: results |> Enum.flat_map(& (&1["signals"] || [])),
      client_names: results |> Enum.flat_map(& (&1["client_names"] || [])) |> Enum.uniq()
    }

    case consolidate(raw) do
      {:ok, consolidated} -> consolidated
      {:error, _} ->
        %{summary: List.first(raw.summaries) || "", action_items: raw.action_items, signals: raw.signals, client_names: raw.client_names}
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
end
