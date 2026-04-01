defmodule Hub.Repo.Migrations.CreateRawDocuments do
  use Ecto.Migration

  def change do
    create table(:raw_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :string, null: false
      add :source_id, :string, null: false
      add :content, :text, null: false
      add :segments, :jsonb, default: "[]"
      add :participants, :jsonb, default: "[]"
      add :metadata, :jsonb, default: "{}"
      add :ingested_at, :utc_datetime_usec, null: false, default: fragment("now()")

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:raw_documents, [:source, :source_id])
    create index(:raw_documents, [:source])
    create index(:raw_documents, [:ingested_at])
  end
end
