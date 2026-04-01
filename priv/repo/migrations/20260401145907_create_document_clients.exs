defmodule Hub.Repo.Migrations.CreateDocumentClients do
  use Ecto.Migration

  def change do
    create table(:document_clients, primary_key: false) do
      add :raw_document_id, references(:raw_documents, type: :binary_id, on_delete: :delete_all), null: false
      add :client_id, references(:clients, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:document_clients, [:raw_document_id, :client_id])
    create index(:document_clients, [:client_id])
  end
end
