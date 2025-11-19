defmodule NumbersEvolution.Repo.Migrations.AddIsFavoriteToSimulations do
  use Ecto.Migration

  def change do
    alter table(:simulations) do
      add :is_favorite, :boolean, default: false, null: false
    end
  end
end
