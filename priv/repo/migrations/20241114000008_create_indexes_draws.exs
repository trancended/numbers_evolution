defmodule NumbersEvolution.Repo.Migrations.CreateIndexesDraws do
  use Ecto.Migration

  def change do
    # Filtrowanie po game_type
    create index(:draws, [:game_type], name: :idx_draws_game_type)

    # Sortowanie chronologiczne (najnowsze najpierw) - używamy raw SQL dla DESC
    execute "CREATE INDEX idx_draws_date_desc ON draws (draw_date DESC)",
            "DROP INDEX IF EXISTS idx_draws_date_desc"

    # GIN index dla queries po numbers
    execute "CREATE INDEX idx_draws_numbers_gin ON draws USING GIN(numbers)",
            "DROP INDEX IF EXISTS idx_draws_numbers_gin"
  end
end
