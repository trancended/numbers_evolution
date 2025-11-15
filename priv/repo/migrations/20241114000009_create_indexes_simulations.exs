defmodule NumbersEvolution.Repo.Migrations.CreateIndexesSimulations do
  use Ecto.Migration

  def change do
    # Filtrowanie po użytkowniku (najczęstsze)
    create index(:simulations, [:user_id], name: :idx_simulations_user_id)

    # Filtrowanie po strategii (partial - tylko non-null)
    create index(:simulations, [:strategy_id],
      name: :idx_simulations_strategy_id,
      where: "strategy_id IS NOT NULL")

    # Sortowanie chronologiczne (historia symulacji) - używamy raw SQL dla DESC
    execute "CREATE INDEX idx_simulations_inserted_at_desc ON simulations (inserted_at DESC)",
            "DROP INDEX IF EXISTS idx_simulations_inserted_at_desc"

    # Composite: user + strategy + status (dla filtrowania i agregacji)
    create index(:simulations, [:user_id, :strategy_id, :status],
      name: :idx_simulations_user_strategy_status)

    # Filtrowanie po statusie
    create index(:simulations, [:status], name: :idx_simulations_status)

    # Performance: dla przeliczania performance_score
    create index(:simulations, [:strategy_id, :attempts_count],
      name: :idx_simulations_strategy_attempts,
      where: "status = 'success'")
  end
end
