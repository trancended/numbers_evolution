defmodule NumbersEvolution.Repo.Migrations.CreateTriggerUpdatedAt do
  use Ecto.Migration

  def up do
    # Tworzenie funkcji dla automatycznej aktualizacji updated_at
    execute """
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Trigger dla users
    execute """
    CREATE TRIGGER update_users_updated_at
      BEFORE UPDATE ON users
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
    """

    # Trigger dla strategies
    execute """
    CREATE TRIGGER update_strategies_updated_at
      BEFORE UPDATE ON strategies
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
    """

    # Trigger dla draws
    execute """
    CREATE TRIGGER update_draws_updated_at
      BEFORE UPDATE ON draws
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
    """

    # Trigger dla simulations
    execute """
    CREATE TRIGGER update_simulations_updated_at
      BEFORE UPDATE ON simulations
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS update_simulations_updated_at ON simulations"
    execute "DROP TRIGGER IF EXISTS update_draws_updated_at ON draws"
    execute "DROP TRIGGER IF EXISTS update_strategies_updated_at ON strategies"
    execute "DROP TRIGGER IF EXISTS update_users_updated_at ON users"
    execute "DROP FUNCTION IF EXISTS update_updated_at_column()"
  end
end
