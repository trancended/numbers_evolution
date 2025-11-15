defmodule NumbersEvolution.Repo.Migrations.CreateStrategies do
  use Ecto.Migration

  def change do
    create table(:strategies, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :name, :string, size: 255, null: false
      add :type, :string, size: 50, null: false
      add :status, :string, size: 50, null: false, default: "active"
      add :rules, :jsonb, null: false
      add :ai_prompt, :text
      add :performance_score, :float

      timestamps(type: :utc_datetime)
    end

    create constraint(:strategies, :strategies_type_check,
      check: "type IN ('manual', 'ai_generated')")

    create constraint(:strategies, :strategies_status_check,
      check: "status IN ('active', 'deleted', 'archived')")
  end
end
