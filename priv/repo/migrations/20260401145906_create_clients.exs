defmodule Hub.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :aliases, :jsonb, default: "[]"
      add :metadata, :jsonb, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:clients, [:name])
  end
end
