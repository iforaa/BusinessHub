defmodule Hub.Pipeline.Processor do
  use Oban.Worker, queue: :pipeline, max_attempts: 3

  alias Hub.Documents.{RawDocument, ProcessedDocument, Signal}
  alias Hub.Clients.Resolver
  alias Hub.People.Resolver, as: PeopleResolver
  alias Hub.Pipeline.{Chunker, Extractor, Merger}
  alias Hub.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"raw_document_id" => raw_doc_id} = args}) do
    if Repo.get_by(ProcessedDocument, raw_document_id: raw_doc_id) do
      Logger.info("Document #{raw_doc_id} already processed, skipping")
      :ok
    else
      perform_extraction(raw_doc_id, args)
    end
  end

  defp perform_extraction(raw_doc_id, args) do
    raw_doc = Repo.get!(RawDocument, raw_doc_id)

    with {:ok, extraction} <- extract(raw_doc, args),
         {:ok, processed_doc} <- store_processed(raw_doc, extraction),
         :ok <- store_signals(processed_doc, extraction.signals),
         :ok <- Resolver.resolve_and_link(raw_doc, extraction.client_names),
         :ok <- PeopleResolver.resolve_and_link(raw_doc, raw_doc.participants) do
      Hub.Cache.invalidate("feed:documents")
      Hub.Cache.invalidate_prefix("feed:person:")
      Hub.Cache.invalidate("people:sidebar")
      Hub.Cache.invalidate("doc:#{raw_doc_id}")
      Phoenix.PubSub.broadcast(Hub.PubSub, "documents", {:document_processed, processed_doc.id})
      Logger.info("Processed document #{raw_doc_id} — #{length(extraction.signals)} signals extracted")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to process document #{raw_doc_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract(_raw_doc, %{"test_extraction" => test_data}) do
    {:ok, Merger.merge([test_data], %{})}
  end

  defp extract(raw_doc, _args) do
    chunks = Chunker.chunk(raw_doc.segments)

    results =
      Enum.map(chunks, fn chunk_segments ->
        text = chunk_segments |> Enum.map(fn s -> "#{s["speaker"]}: #{s["text"]}" end) |> Enum.join("\n")
        case Extractor.extract(text, participants: raw_doc.participants, metadata: raw_doc.metadata) do
          {:ok, result} -> result
          {:error, reason} -> raise "Extraction failed: #{inspect(reason)}"
        end
      end)

    {:ok, Merger.merge(results, raw_doc.metadata)}
  end

  defp store_processed(raw_doc, extraction) do
    %ProcessedDocument{}
    |> ProcessedDocument.changeset(%{
      raw_document_id: raw_doc.id,
      summary: extraction.summary,
      ai_title: extraction[:ai_title],
      action_items: extraction.action_items,
      model: Application.get_env(:hub, :claude)[:model] || "claude-sonnet-4-6-20250627",
      prompt_version: Extractor.prompt_version(),
      processed_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp store_signals(processed_doc, signals) do
    Enum.each(signals, fn signal_data ->
      %Signal{}
      |> Signal.changeset(%{
        processed_document_id: processed_doc.id,
        type: signal_data["type"],
        content: signal_data["content"],
        speaker: signal_data["speaker"],
        confidence: signal_data["confidence"],
        metadata: Map.drop(signal_data, ["type", "content", "speaker", "confidence"])
      })
      |> Repo.insert!()
    end)

    :ok
  end
end
