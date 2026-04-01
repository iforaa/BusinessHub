defmodule Hub.Repo.Migrations.CreateDocumentPeople do
  use Ecto.Migration

  def change do
    create table(:document_people, primary_key: false) do
      add :raw_document_id, references(:raw_documents, type: :binary_id, on_delete: :delete_all), null: false
      add :person_id, references(:people, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:document_people, [:raw_document_id, :person_id])
    create index(:document_people, [:person_id])
  end
end
