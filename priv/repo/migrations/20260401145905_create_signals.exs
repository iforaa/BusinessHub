defmodule Hub.Repo.Migrations.CreateSignals do
  use Ecto.Migration

  def change do
    create table(:signals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :processed_document_id, references(:processed_documents, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :content, :text, null: false
      add :speaker, :string
      add :confidence, :float
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:signals, [:type])
    create index(:signals, [:processed_document_id])
  end
end
