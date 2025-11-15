defmodule NumbersEvolution.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :event_type, :string, size: 100, null: false
      add :metadata, :jsonb

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create constraint(:events, :events_type_check,
      check: """
      event_type IN (
        'strategy_created',
        'strategy_updated',
        'strategy_deleted',
        'simulation_started',
        'simulation_completed',
        'coupons_generated',
        'strategy_mix_created',
        'ai_request',
        'ai_success',
        'ai_error'
      )
      """)
  end
end
