defmodule Hub.Pipeline.Extractor do
  alias Hub.Claude
  alias Hub.People.Roster

  @prompt_version "v2"

  def extract(transcript_text, opts \\ []) do
    system = build_system_prompt()
    prompt = build_prompt(transcript_text, opts)

    case Claude.Client.chat(prompt, system: system) do
      {:ok, response} -> parse_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  def prompt_version, do: @prompt_version

  defp build_system_prompt do
    """
    You are analyzing a meeting transcript from TenFore, a golf course management software company. Extract structured data as JSON.

    TenFore employees:
    #{Roster.employees_prompt()}

    Known clients:
    #{Roster.clients_prompt()}

    Anyone not in these lists is likely a client or external participant.
    """
  end

  def build_prompt(transcript_text, opts \\ []) do
    participants = opts[:participants] || []
    metadata = opts[:metadata] || %{}

    """
    Participants: #{Enum.join(participants, ", ")}
    Meeting topic: #{metadata["topic"] || "Unknown"}
    Date: #{metadata["start_time"] || "Unknown"}

    Extract the following as JSON (no markdown, just raw JSON):
    - summary: 2-3 sentence summary focused on decisions and outcomes
    - action_items: [{text, person (if someone was mentioned, otherwise omit)}]
    - signals: [{type, content (a meaningful paraphrase with enough context to understand standalone), speaker, confidence (0.0-1.0)}]
    - client_names: any golf course or client names mentioned

    Signal extraction rules:
    - Each signal must be self-contained and meaningful without reading the transcript
    - Group related mentions into ONE signal (e.g. multiple quotes about the same competitor = one signal)
    - Commitments must include a specific deliverable — skip vague affirmations like "I'll do it" or "sure"
    - Only extract signals with real business value — skip casual conversation, jokes, small talk
    - Prefer fewer high-quality signals over many low-quality ones

    Signal types:
    - feature_request: someone asks for something that doesn't exist
    - bug_report: something isn't working as expected (include what specifically is broken)
    - competitor_mention: reference to competing products (consolidate into one signal per competitor)
    - churn_signal: client dissatisfaction, evaluating alternatives
    - commitment: someone promises a specific deliverable (must name what will be done)
    - positive_feedback: satisfaction expressed about a specific feature or outcome
    - pricing_discussion: conversation about pricing, costs, or billing
    - onboarding_issue: problems during client setup or training

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
