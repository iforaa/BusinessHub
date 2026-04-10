defmodule Hub.Claude.Client do
  require Logger

  @api_url "https://api.anthropic.com/v1/messages"
  @api_version "2023-06-01"
  @default_max_tokens 4096

  def chat(user_message, opts \\ []) do
    body = build_request(user_message, opts)

    case Req.post(@api_url,
      json: body,
      headers: headers(),
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

  def stream(user_message, opts \\ []) do
    on_chunk = opts[:on_chunk] || fn _ -> :ok end
    body = build_request(user_message, opts) |> Map.put(:stream, true)

    Req.post(@api_url,
      json: body,
      headers: headers(),
      receive_timeout: 120_000,
      into: fn {:data, data}, acc ->
        data
        |> String.split("\n")
        |> Enum.each(fn line ->
          case parse_sse(line) do
            {:text, text} -> on_chunk.(text)
            _ -> :ok
          end
        end)
        {:cont, acc}
      end
    )
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_sse("data: " <> json) do
    case Jason.decode(json) do
      {:ok, %{"type" => "content_block_delta", "delta" => %{"text" => text}}} ->
        {:text, text}
      _ -> :skip
    end
  end
  defp parse_sse(_), do: :skip

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

  defp headers do
    [
      {"x-api-key", api_key()},
      {"anthropic-version", @api_version},
      {"content-type", "application/json"}
    ]
  end

  defp api_key do
    Application.fetch_env!(:hub, :claude)[:api_key]
  end

  defp default_model do
    Application.fetch_env!(:hub, :claude)[:model] || "claude-sonnet-4-20250514"
  end
end
