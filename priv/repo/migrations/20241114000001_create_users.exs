defmodule NumbersEvolution.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", "DROP EXTENSION IF EXISTS \"uuid-ossp\""
    execute "CREATE EXTENSION IF NOT EXISTS \"citext\"", "DROP EXTENSION IF EXISTS \"citext\""

    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end
