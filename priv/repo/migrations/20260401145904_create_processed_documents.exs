defmodule Hub.Repo.Migrations.CreateProcessedDocuments do
  use Ecto.Migration

  def change do
    create table(:processed_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :raw_document_id, references(:raw_documents, type: :binary_id, on_delete: :delete_all), null: false
      add :summary, :text
      add :action_items, :jsonb, default: "[]"
      add :model, :string
      add :prompt_version, :string
      add :processed_at, :utc_datetime_usec, null: false, default: fragment("now()")

      timestamps(type: :utc_datetime_usec)
    end

    create index(:processed_documents, [:raw_document_id])
  end
end
