defmodule Hub.Documents.AiSearch do
  alias Hub.Claude
  alias Hub.Documents.{RawDocument, TranscriptChunk}
  alias Hub.Embeddings.Client, as: EmbeddingsClient
  alias Hub.People.Roster
  alias Hub.Repo

  import Ecto.Query

  require Logger

  @max_context_chars 30_000

  def query(question, opts \\ []) do
    on_step = opts[:on_step] || fn _ -> :ok end
    user = opts[:user]

    on_step.("embedding")
    chunks = retrieve_chunks(question, on_step)

    if chunks == [] do
      {:ok, %{answer: "I couldn't find any relevant conversations for that question.", sources: []}}
    else
      on_step.("context")
      context = build_context(chunks)
      system = build_system_prompt(user)
      prompt = build_prompt(question, context)

      on_stream = opts[:on_stream]

      if on_stream do
        on_step.("thinking")
        full_text = stream_answer(prompt, system, on_stream)
        on_step.("done")
        {:ok, parse_answer(full_text, chunks)}
      else
        on_step.("thinking")
        case Claude.Client.chat(prompt, system: system, max_tokens: 2048) do
          {:ok, response} ->
            on_step.("done")
            {:ok, parse_answer(response, chunks)}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end

  defp retrieve_chunks(question, on_step) do
    case retrieve_by_embedding(question) do
      {:ok, results} when results != [] ->
        on_step.("searching")
        results
      _ ->
        on_step.("searching")
        retrieve_by_fts(question)
    end
  end

  defp retrieve_by_embedding(question) do
    # Check if we have any embeddings
    has_embeddings = Repo.aggregate(TranscriptChunk, :count) > 0

    if has_embeddings do
      case EmbeddingsClient.embed_one(question) do
        {:ok, embedding} ->
          results =
            Repo.query!("""
              SELECT tc.raw_document_id, tc.content, rd.metadata, rd.participants,
                     1 - (tc.embedding <=> $1::vector) as similarity
              FROM transcript_chunks tc
              JOIN raw_documents rd ON rd.id = tc.raw_document_id
              WHERE tc.embedding IS NOT NULL
              ORDER BY tc.embedding <=> $1::vector
              LIMIT 20
            """, [Pgvector.new(embedding)])

          chunks =
            results.rows
            |> Enum.map(fn [doc_id, content, metadata, participants, similarity] ->
              {:ok, uuid} = Ecto.UUID.load(doc_id)
              %{id: uuid, content: content, metadata: metadata, participants: participants, similarity: similarity}
            end)
            # Group by document, keep best chunk per doc
            |> Enum.group_by(& &1.id)
            |> Enum.map(fn {_id, doc_chunks} ->
              best = Enum.max_by(doc_chunks, & &1.similarity)
              combined_content = doc_chunks |> Enum.map(& &1.content) |> Enum.join("\n\n")
              %{best | content: combined_content}
            end)
            |> Enum.sort_by(& &1.similarity, :desc)
            |> Enum.take(10)

          {:ok, chunks}

        {:error, reason} ->
          Logger.warning("Embedding failed, falling back to FTS: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :no_embeddings}
    end
  end

  defp retrieve_by_fts(question) do
    words =
      question
      |> String.replace(~r/[^\w\s]/, " ")
      |> String.split(~r/\s+/, trim: true)
      |> Enum.reject(&(String.length(&1) < 3))

    case words do
      [] -> []
      words ->
        tsquery = words |> Enum.map(&(&1 <> ":*")) |> Enum.join(" | ")

        from(rd in RawDocument,
          where: fragment("search_vector @@ to_tsquery('english', ?)", ^tsquery),
          select: %{
            id: rd.id,
            content: rd.content,
            metadata: rd.metadata,
            participants: rd.participants,
            similarity: fragment("ts_rank(search_vector, to_tsquery('english', ?))", ^tsquery)
          },
          order_by: [desc: fragment("ts_rank(search_vector, to_tsquery('english', ?))", ^tsquery)],
          limit: 10
        )
        |> Repo.all()
    end
  end

  defp stream_answer(prompt, system, on_stream) do
    {:ok, agent} = Agent.start_link(fn -> {"", 0} end)

    try do
      Claude.Client.stream(prompt,
        system: system,
        max_tokens: 2048,
        on_chunk: fn text ->
          {full, should_send} = Agent.get_and_update(agent, fn {acc, last_sent} ->
            new = acc <> text
            now = System.monotonic_time(:millisecond)
            if now - last_sent > 80 do
              {{new, true}, {new, now}}
            else
              {{new, false}, {new, last_sent}}
            end
          end)
          if should_send, do: on_stream.(full)
        end
      )

      {result, _} = Agent.get(agent, & &1)
      on_stream.(result)
      result
    after
      Agent.stop(agent)
    end
  end

  defp build_context(chunks) do
    chunks
    |> Enum.with_index(1)
    |> Enum.reduce({"", 0}, fn {chunk, idx}, {acc, total_chars} ->
      header = "[#{idx}] #{chunk.metadata["topic"] || "Meeting"} — #{chunk.metadata["start_time"] || "Unknown date"} — #{Enum.join(chunk.participants, ", ")}"
      max_per_doc = div(@max_context_chars, min(length(chunks), 10))
      content = String.slice(chunk.content, 0, max_per_doc)
      section = "#{header}\n#{content}\n\n"

      new_total = total_chars + String.length(section)
      if new_total > @max_context_chars do
        {acc, total_chars}
      else
        {acc <> section, new_total}
      end
    end)
    |> elem(0)
  end

  defp build_system_prompt(user) do
    user_line = if user, do: "The person asking is #{user.name} (#{user.email}).", else: ""

    """
    You are an AI assistant for TenFore, a golf course management software company. You answer questions about what was discussed in team meetings.

    Today's date: #{Date.utc_today() |> Date.to_iso8601()}
    #{user_line}

    TenFore employees:
    #{Roster.employees_prompt()}

    TenFore products:
    - Fox: booking frontend (web)
    - Swan: backend API
    - Birdie: legacy tee sheet app
    - Buck: new tee sheet app (web + mobile)
    - Crane: mobile app (iOS/Android)
    - Jackrabbit: internal tools

    When answering:
    - Be concise and direct
    - Reference specific conversations using [1], [2], etc. citations
    - Use relative dates when helpful ("last week", "3 days ago") since you know today's date
    - If the person asking was mentioned in the transcripts, use "you" instead of their name
    - If the transcripts don't contain relevant information, say so
    - Focus on facts from the transcripts, don't speculate
    """
  end

  defp build_prompt(question, context) do
    """
    Based on these meeting transcripts, answer the following question:

    Question: #{question}

    Transcripts:
    #{context}
    """
  end

  defp parse_answer(response, chunks) do
    sources =
      chunks
      |> Enum.with_index(1)
      |> Enum.map(fn {chunk, idx} ->
        %{
          index: idx,
          id: chunk.id,
          topic: chunk.metadata["topic"] || "Meeting",
          start_time: chunk.metadata["start_time"]
        }
      end)

    %{answer: response, sources: sources}
  end
end
