defmodule NumbersEvolution.Repo.Migrations.AddDescriptionToStrategies do
  use Ecto.Migration

  def change do
    alter table(:strategies) do
      add :description, :text
    end
  end
end
