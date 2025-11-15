defmodule NumbersEvolution.Repo.Migrations.AddPreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :preferences, :jsonb
    end
  end
end
