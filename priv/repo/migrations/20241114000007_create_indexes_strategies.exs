defmodule NumbersEvolution.Repo.Migrations.CreateIndexesStrategies do
  use Ecto.Migration

  def change do
    # Filtrowanie po użytkowniku (najczęstsze query)
    create index(:strategies, [:user_id], name: :idx_strategies_user_id)

    # Filtrowanie po typie
    create index(:strategies, [:type], name: :idx_strategies_type)

    # Filtrowanie po statusie (partial index - tylko active)
    create index(:strategies, [:status],
             name: :idx_strategies_status_active,
             where: "status = 'active'"
           )

    # Sortowanie po performance_score (rankingi)
    create index(:strategies, [:performance_score],
             name: :idx_strategies_performance_score,
             where: "performance_score IS NOT NULL"
           )

    # Composite index: user + performance (ranking per user)
    create index(:strategies, [:user_id, :performance_score],
             name: :idx_strategies_user_performance
           )

    # GIN index dla JSONB queries
    execute "CREATE INDEX idx_strategies_rules_gin ON strategies USING GIN(rules)",
            "DROP INDEX IF EXISTS idx_strategies_rules_gin"
  end
end
