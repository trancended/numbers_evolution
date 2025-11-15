defmodule NumbersEvolution.Repo.Migrations.CreateDraws do
  use Ecto.Migration

  def change do
    create table(:draws, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :draw_date, :date, null: false
      add :game_type, :string, size: 50, null: false
      add :numbers, :jsonb, null: false
      add :source, :string, size: 50

      timestamps(type: :utc_datetime)
    end

    create unique_index(:draws, [:game_type, :draw_date], name: :draws_game_date_unique)
  end
end
