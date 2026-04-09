defmodule Hub.Repo.Migrations.AddTranscriptChunks do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    create table(:transcript_chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :raw_document_id, references(:raw_documents, type: :binary_id, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :chunk_index, :integer, null: false
      add :start_ms, :integer
      add :end_ms, :integer
      add :embedding, :"vector(1024)"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:transcript_chunks, [:raw_document_id])
    execute "CREATE INDEX transcript_chunks_embedding_idx ON transcript_chunks USING hnsw (embedding vector_cosine_ops)"
  end

  def down do
    drop table(:transcript_chunks)
  end
end
