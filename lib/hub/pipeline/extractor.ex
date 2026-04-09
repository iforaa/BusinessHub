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
    - signals: [{type, content (exact quote or close paraphrase), speaker, confidence (0.0-1.0)}]
    - client_names: any golf course or client names mentioned

    Signal types:
    - feature_request: someone asks for something that doesn't exist
    - bug_report: something isn't working as expected
    - competitor_mention: reference to competing products
    - churn_signal: dissatisfaction, evaluating alternatives
    - commitment: someone promises to do something
    - positive_feedback: satisfaction expressed
    - pricing_discussion: conversation about pricing or costs
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
