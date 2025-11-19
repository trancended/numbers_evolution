defmodule NumbersEvolution.Repo.Migrations.AddOptionsToSimulations do
  use Ecto.Migration

  def change do
    alter table(:simulations) do
      add :options, :jsonb, default: "{}"
    end
  end
end
