defmodule NumbersEvolution.Repo.Migrations.CreateSimulations do
  use Ecto.Migration

  def change do
    create table(:simulations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :strategy_id, references(:strategies, type: :uuid, on_delete: :nilify_all)
      add :target_draw_id, references(:draws, type: :uuid, on_delete: :delete_all), null: false
      add :attempts_count, :bigint, null: false, default: 0
      add :duration_seconds, :float, null: false, default: 0.0
      add :status, :string, size: 50, null: false
      add :result, :jsonb
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create constraint(:simulations, :simulations_status_check,
             check: "status IN ('pending', 'running', 'success', 'timeout', 'error', 'cancelled')"
           )

    create constraint(:simulations, :simulations_attempts_check, check: "attempts_count >= 0")

    create constraint(:simulations, :simulations_duration_check, check: "duration_seconds >= 0")

    create constraint(:simulations, :simulations_completed_check,
             check: "completed_at IS NULL OR completed_at >= started_at"
           )
  end
end
