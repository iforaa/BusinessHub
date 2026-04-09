defmodule Hub.Repo.Migrations.AddAvatarUrlToPeople do
  use Ecto.Migration

  def change do
    alter table(:people) do
      add :avatar_url, :text
    end
  end
end
