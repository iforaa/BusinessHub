defmodule Hub.Pipeline.Extractor do
  alias Hub.Claude

  @prompt_version "v1"

  @system_prompt """
  You are analyzing a transcript from a client conversation at TenFore, a golf course management software company. Extract structured data as JSON.
  """

  def extract(transcript_text, opts \\ []) do
    prompt = build_prompt(transcript_text, opts)

    case Claude.Client.chat(prompt, system: @system_prompt) do
      {:ok, response} -> parse_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  def prompt_version, do: @prompt_version

  def build_prompt(transcript_text, opts \\ []) do
    participants = opts[:participants] || []
    metadata = opts[:metadata] || %{}

    """
    TenFore — Golf Course Management Software
    Participants: #{Enum.join(participants, ", ")}
    Meeting topic: #{metadata["topic"] || "Unknown"}
    Date: #{metadata["start_time"] || "Unknown"}

    Extract the following as JSON (no markdown, just raw JSON):
    - summary: 2-3 sentence summary of this segment
    - action_items: [{text, assignee (if mentioned), due_date (if mentioned)}]
    - signals: [{type, content (exact quote or close paraphrase), speaker, confidence (0.0-1.0)}]
    - client_names: any golf course / client names mentioned

    Signal types:
    - feature_request: client asks for something that doesn't exist
    - bug_report: something isn't working as expected
    - competitor_mention: reference to competing products
    - churn_signal: dissatisfaction, evaluating alternatives
    - commitment: someone promises to do something by a date
    - positive_feedback: client expresses satisfaction

    Transcript:
    #{transcript_text}
    """
  end

  def parse_response(response) do
    case Jason.decode(response) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, _} ->
        case Regex.run(~r/```(?:json)?\s*\n?(.*?)\n?```/s, response) do
          [_, json_str] -> Jason.decode(json_str)
          nil -> {:error, "Could not parse Claude response as JSON: #{String.slice(response, 0, 200)}"}
        end
    end
  end
end
