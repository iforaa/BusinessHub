defmodule Hub.Repo.Migrations.AddRoleAndContextToPeople do
  use Ecto.Migration

  def change do
    alter table(:people) do
      add :role, :string, default: "unknown"
      add :context, :text, default: ""
    end
  end
end
