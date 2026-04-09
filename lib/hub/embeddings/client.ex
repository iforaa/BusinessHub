defmodule Hub.Embeddings.Client do
  @openrouter_url "https://openrouter.ai/api/v1/embeddings"
  @model "openai/text-embedding-3-small"

  require Logger

  def embed(texts) when is_list(texts) do
    body = %{input: texts, model: @model}

    case Req.post(@openrouter_url,
      json: body,
      headers: [
        {"Authorization", "Bearer #{api_key()}"},
        {"content-type", "application/json"}
      ],
      receive_timeout: 60_000
    ) do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        embeddings = data |> Enum.sort_by(& &1["index"]) |> Enum.map(& &1["embedding"])
        {:ok, embeddings}

      {:ok, %{status: status, body: body}} ->
        Logger.error("OpenRouter embeddings error #{status}: #{inspect(body)}")
        {:error, "OpenRouter error: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def embed_one(text) do
    case embed([text]) do
      {:ok, [embedding]} -> {:ok, embedding}
      error -> error
    end
  end

  defp api_key do
    Application.get_env(:hub, :openrouter, [])[:api_key] ||
      System.get_env("OPENROUTER_API_KEY")
  end
end
