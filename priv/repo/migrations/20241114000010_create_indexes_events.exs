defmodule NumbersEvolution.Repo.Migrations.CreateIndexesEvents do
  use Ecto.Migration

  def change do
    # Composite: user + data (analiza aktywności użytkownika) - używamy raw SQL dla custom ordering
    execute "CREATE INDEX idx_events_user_date ON events (user_id ASC, inserted_at DESC)",
            "DROP INDEX IF EXISTS idx_events_user_date"

    # Filtrowanie po typie eventu
    create index(:events, [:event_type], name: :idx_events_type)

    # GIN index dla queries po metadata
    execute "CREATE INDEX idx_events_metadata_gin ON events USING GIN(metadata)",
            "DROP INDEX IF EXISTS idx_events_metadata_gin"
  end
end
