defmodule Hub.Embeddings.Worker do
  use Oban.Worker, queue: :pipeline, max_attempts: 3

  alias Hub.Documents.{RawDocument, TranscriptChunk}
  alias Hub.Embeddings.Client
  alias Hub.Repo

  import Ecto.Query

  require Logger

  @chunk_size 500
  @chunk_overlap 50
  @batch_size 20

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"raw_document_id" => raw_doc_id}}) do
    # Skip if already chunked
    existing = Repo.aggregate(from(tc in TranscriptChunk, where: tc.raw_document_id == ^raw_doc_id), :count)

    if existing > 0 do
      Logger.info("Embeddings already exist for #{raw_doc_id}, skipping")
      :ok
    else
      raw_doc = Repo.get!(RawDocument, raw_doc_id)
      chunks = chunk_content(raw_doc)

      Logger.info("Generating embeddings for #{raw_doc.metadata["topic"] || raw_doc_id} (#{length(chunks)} chunks)")

      chunks
      |> Enum.chunk_every(@batch_size)
      |> Enum.each(fn batch ->
        texts = Enum.map(batch, & &1.content)

        case Client.embed(texts) do
          {:ok, embeddings} ->
            Enum.zip(batch, embeddings)
            |> Enum.each(fn {chunk, embedding} ->
              inserted =
                %TranscriptChunk{}
                |> TranscriptChunk.changeset(chunk)
                |> Repo.insert!()

              {:ok, id_bin} = Ecto.UUID.dump(inserted.id)
              Repo.query!(
                "UPDATE transcript_chunks SET embedding = $1::vector WHERE id = $2",
                [Pgvector.new(embedding), id_bin]
              )
            end)

          {:error, reason} ->
            Logger.error("Embedding batch failed: #{inspect(reason)}")
            raise "Embedding failed: #{inspect(reason)}"
        end
      end)

      Logger.info("Embeddings complete for #{raw_doc_id}")
      :ok
    end
  end

  defp chunk_content(doc) do
    words = String.split(doc.content, ~r/\s+/)

    if length(words) <= @chunk_size do
      [%{raw_document_id: doc.id, content: doc.content, chunk_index: 0}]
    else
      do_chunk(words, doc.id, 0, [])
    end
  end

  defp do_chunk(words, doc_id, index, acc) when length(words) <= @chunk_size do
    chunk = %{raw_document_id: doc_id, content: Enum.join(words, " "), chunk_index: index}
    Enum.reverse([chunk | acc])
  end

  defp do_chunk(words, doc_id, index, acc) do
    {chunk_words, rest} = Enum.split(words, @chunk_size)
    overlap = Enum.take(chunk_words, -@chunk_overlap)
    chunk = %{raw_document_id: doc_id, content: Enum.join(chunk_words, " "), chunk_index: index}
    do_chunk(overlap ++ rest, doc_id, index + 1, [chunk | acc])
  end
end
