defmodule NumbersEvolution.Repo.Migrations.UpdateSimulationsStatusConstraint do
  use Ecto.Migration

  def up do
    drop constraint(:simulations, :simulations_status_check)

    create constraint(:simulations, :simulations_status_check,
             check: "status IN ('pending', 'running', 'success', 'timeout', 'max_attempts_reached', 'error', 'cancelled')"
           )
  end

  def down do
    drop constraint(:simulations, :simulations_status_check)

    create constraint(:simulations, :simulations_status_check,
             check: "status IN ('pending', 'running', 'success', 'timeout', 'error', 'cancelled')"
           )
  end
end
