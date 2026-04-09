defmodule Mix.Tasks.Hub.Embed do
  @moduledoc "Chunk transcripts and generate embeddings for semantic search"
  use Mix.Task

  @shortdoc "Generate transcript embeddings"
  @chunk_size 500
  @chunk_overlap 50
  @batch_size 20

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    alias Hub.Documents.{RawDocument, TranscriptChunk}
    alias Hub.Embeddings.Client
    alias Hub.Repo

    import Ecto.Query

    # Find documents without chunks
    already_chunked =
      from(tc in TranscriptChunk, select: tc.raw_document_id, distinct: true)
      |> Repo.all()
      |> MapSet.new()

    docs =
      from(rd in RawDocument, select: rd)
      |> Repo.all()
      |> Enum.reject(&MapSet.member?(already_chunked, &1.id))

    Mix.shell().info("Found #{length(docs)} document(s) to embed")

    all_chunks =
      Enum.flat_map(docs, fn doc ->
        topic = doc.metadata["topic"] || "Meeting"
        Mix.shell().info("  Chunking: #{topic}")
        chunk_document(doc)
      end)

    Mix.shell().info("Created #{length(all_chunks)} chunks, generating embeddings...")

    # Insert chunks and generate embeddings in batches
    all_chunks
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, batch_idx} ->
      texts = Enum.map(batch, & &1.content)

      case Client.embed(texts) do
        {:ok, embeddings} ->
          Enum.zip(batch, embeddings)
          |> Enum.each(fn {chunk, embedding} ->
            %TranscriptChunk{}
            |> TranscriptChunk.changeset(chunk)
            |> Repo.insert!()
            |> then(fn inserted ->
              {:ok, id_bin} = Ecto.UUID.dump(inserted.id)
              Repo.query!(
                "UPDATE transcript_chunks SET embedding = $1::vector WHERE id = $2",
                [Pgvector.new(embedding), id_bin]
              )
            end)
          end)

          Mix.shell().info("  Batch #{batch_idx}: #{length(batch)} chunks embedded")

        {:error, reason} ->
          Mix.shell().error("  Batch #{batch_idx} failed: #{inspect(reason)}")
      end

      # Rate limit
      Process.sleep(500)
    end)

    total = Repo.aggregate(TranscriptChunk, :count)
    Mix.shell().info("Done. Total chunks in DB: #{total}")
  end

  defp chunk_document(doc) do
    words = String.split(doc.content, ~r/\s+/)

    if length(words) <= @chunk_size do
      [%{raw_document_id: doc.id, content: doc.content, chunk_index: 0, start_ms: nil, end_ms: nil}]
    else
      chunk_words(words, doc.id, 0, [])
    end
  end

  defp chunk_words(words, doc_id, index, acc) when length(words) <= @chunk_size do
    chunk = %{
      raw_document_id: doc_id,
      content: Enum.join(words, " "),
      chunk_index: index,
      start_ms: nil,
      end_ms: nil
    }
    Enum.reverse([chunk | acc])
  end

  defp chunk_words(words, doc_id, index, acc) do
    {chunk_words, rest} = Enum.split(words, @chunk_size)
    # Overlap: prepend last N words of this chunk to next
    overlap = Enum.take(chunk_words, -@chunk_overlap)

    chunk = %{
      raw_document_id: doc_id,
      content: Enum.join(chunk_words, " "),
      chunk_index: index,
      start_ms: nil,
      end_ms: nil
    }

    chunk_words(overlap ++ rest, doc_id, index + 1, [chunk | acc])
  end
end
