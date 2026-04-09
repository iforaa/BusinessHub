defmodule Hub.Repo.Migrations.FixEmbeddingDimension do
  use Ecto.Migration

  def up do
    execute "DROP INDEX IF EXISTS transcript_chunks_embedding_idx"
    execute "ALTER TABLE transcript_chunks ALTER COLUMN embedding TYPE vector(1536)"
    execute "CREATE INDEX transcript_chunks_embedding_idx ON transcript_chunks USING hnsw (embedding vector_cosine_ops)"
  end

  def down do
    execute "DROP INDEX IF EXISTS transcript_chunks_embedding_idx"
    execute "ALTER TABLE transcript_chunks ALTER COLUMN embedding TYPE vector(1024)"
    execute "CREATE INDEX transcript_chunks_embedding_idx ON transcript_chunks USING hnsw (embedding vector_cosine_ops)"
  end
end
