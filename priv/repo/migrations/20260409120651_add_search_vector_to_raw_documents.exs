defmodule Hub.Repo.Migrations.AddSearchVectorToRawDocuments do
  use Ecto.Migration

  def up do
    alter table(:raw_documents) do
      add :search_vector, :tsvector
    end

    create index(:raw_documents, [:search_vector], using: :gin)

    execute """
    CREATE OR REPLACE FUNCTION raw_documents_search_trigger() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector := to_tsvector('english', coalesce(NEW.content, ''));
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER raw_documents_search_update
      BEFORE INSERT OR UPDATE OF content ON raw_documents
      FOR EACH ROW EXECUTE FUNCTION raw_documents_search_trigger();
    """

    execute """
    UPDATE raw_documents SET search_vector = to_tsvector('english', coalesce(content, ''));
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS raw_documents_search_update ON raw_documents;"
    execute "DROP FUNCTION IF EXISTS raw_documents_search_trigger();"

    alter table(:raw_documents) do
      remove :search_vector
    end
  end
end
