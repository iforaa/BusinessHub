defmodule Mix.Tasks.Hub.Process do
  @moduledoc "Process unprocessed transcripts with AI extraction"
  use Mix.Task

  @shortdoc "Process transcripts with AI"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    alias Hub.Documents.{RawDocument, ProcessedDocument}
    alias Hub.Repo

    import Ecto.Query

    case args do
      [id] ->
        raw_doc = Repo.get!(RawDocument, id)
        process_one(raw_doc)

      [] ->
        unprocessed =
          from(rd in RawDocument,
            left_join: pd in ProcessedDocument, on: pd.raw_document_id == rd.id,
            where: is_nil(pd.id),
            select: rd
          )
          |> Repo.all()

        count = length(unprocessed)
        Mix.shell().info("Found #{count} unprocessed document(s)")

        Enum.each(unprocessed, fn raw_doc ->
          process_one(raw_doc)
        end)

        Mix.shell().info("Done processing #{count} document(s)")
    end
  end

  defp process_one(raw_doc) do
    topic = raw_doc.metadata["topic"] || "Untitled"
    Mix.shell().info("Processing: #{topic} (#{raw_doc.id})")

    %{raw_document_id: raw_doc.id}
    |> Hub.Pipeline.Processor.new()
    |> Oban.insert!()
    |> wait_for_job()
  end

  defp wait_for_job(%{id: job_id}) do
    # Poll until the job completes
    Stream.repeatedly(fn ->
      Process.sleep(1000)
      Hub.Repo.get(Oban.Job, job_id)
    end)
    |> Enum.find(fn job ->
      case job.state do
        "completed" ->
          Mix.shell().info("  ✓ Done")
          true
        "discarded" ->
          Mix.shell().error("  ✗ Failed: #{inspect(List.last(job.errors))}")
          true
        _ ->
          false
      end
    end)
  end
end
