defmodule Hub.Repo.Migrations.AddAiTitleToProcessedDocuments do
  use Ecto.Migration

  def change do
    alter table(:processed_documents) do
      add :ai_title, :text
    end
  end
end
