defmodule Hub.Claude.Client do
  require Logger

  @api_url "https://api.anthropic.com/v1/messages"
  @api_version "2023-06-01"
  @default_max_tokens 4096

  def chat(user_message, opts \\ []) do
    body = build_request(user_message, opts)

    case Req.post(@api_url,
      json: body,
      headers: [
        {"x-api-key", api_key()},
        {"anthropic-version", @api_version},
        {"content-type", "application/json"}
      ],
      receive_timeout: 120_000
    ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Claude API returned #{status}: #{inspect(body)}")
        {:error, "Claude API error: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def build_request(user_message, opts \\ []) do
    %{
      model: opts[:model] || default_model(),
      max_tokens: opts[:max_tokens] || @default_max_tokens,
      messages: [%{role: "user", content: user_message}]
    }
    |> maybe_add_system(opts[:system])
  end

  defp maybe_add_system(body, nil), do: body
  defp maybe_add_system(body, system), do: Map.put(body, :system, system)

  defp api_key do
    Application.fetch_env!(:hub, :claude)[:api_key]
  end

  defp default_model do
    Application.fetch_env!(:hub, :claude)[:model] || "claude-sonnet-4-20250514"
  end
end
