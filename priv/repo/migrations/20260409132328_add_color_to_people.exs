defmodule Hub.Repo.Migrations.AddColorToPeople do
  use Ecto.Migration

  def change do
    alter table(:people) do
      add :color, :string
    end

    create unique_index(:people, [:color], where: "color IS NOT NULL")
  end
end
