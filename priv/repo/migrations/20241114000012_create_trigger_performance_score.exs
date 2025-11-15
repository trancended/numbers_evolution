defmodule NumbersEvolution.Repo.Migrations.CreateTriggerPerformanceScore do
  use Ecto.Migration

  def up do
    # Tworzenie funkcji dla automatycznego przeliczania performance_score
    execute """
    CREATE OR REPLACE FUNCTION recalculate_performance_score()
    RETURNS TRIGGER AS $$
    DECLARE
      affected_strategy_id UUID;
      new_score FLOAT;
    BEGIN
      -- Określ którą strategię zaktualizować
      affected_strategy_id := COALESCE(NEW.strategy_id, OLD.strategy_id);

      IF affected_strategy_id IS NOT NULL THEN
        -- Oblicz medianę tylko dla successful simulations
        SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY attempts_count)
        INTO new_score
        FROM simulations
        WHERE strategy_id = affected_strategy_id
          AND status = 'success';

        -- Aktualizuj strategię
        UPDATE strategies
        SET performance_score = new_score,
            updated_at = NOW()
        WHERE id = affected_strategy_id;
      END IF;

      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Trigger dla aktualizacji performance_score
    execute """
    CREATE TRIGGER update_strategy_performance
      AFTER INSERT OR UPDATE OR DELETE ON simulations
      FOR EACH ROW
      EXECUTE FUNCTION recalculate_performance_score();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS update_strategy_performance ON simulations"
    execute "DROP FUNCTION IF EXISTS recalculate_performance_score()"
  end
end
