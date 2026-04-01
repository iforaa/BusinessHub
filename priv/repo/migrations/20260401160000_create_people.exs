defmodule Hub.Repo.Migrations.CreatePeople do
  use Ecto.Migration

  def change do
    create table(:people, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :string
      add :aliases, :jsonb, default: "[]"
      add :metadata, :jsonb, default: "{}"
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:people, [:name])
  end
end
