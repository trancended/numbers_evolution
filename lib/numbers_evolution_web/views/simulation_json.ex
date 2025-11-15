defmodule NumbersEvolutionWeb.SimulationJSON do
  @moduledoc """
  JSON rendering for Simulation resources.
  """

  alias NumbersEvolution.Simulations.Simulation

  @doc """
  Renders a list of simulations.
  """
  def index(%{simulations: simulations, meta: meta}) do
    %{
      data: for(simulation <- simulations, do: data(simulation)),
      meta: meta
    }
  end

  @doc """
  Renders a single simulation.
  """
  def show(%{simulation: simulation}) do
    %{data: data(simulation)}
  end

  @doc """
  Renders simulation progress.
  """
  def progress(%{progress: progress}) do
    %{data: progress}
  end

  defp data(%Simulation{} = simulation) do
    base = %{
      id: simulation.id,
      user_id: simulation.user_id,
      strategy_id: simulation.strategy_id,
      target_draw_id: simulation.target_draw_id,
      status: simulation.status,
      attempts_count: simulation.attempts_count,
      duration_seconds: simulation.duration_seconds,
      started_at: simulation.started_at,
      completed_at: simulation.completed_at,
      inserted_at: simulation.inserted_at
    }

    base
    |> add_result(simulation.result)
    |> add_strategy(simulation)
    |> add_target_draw(simulation)
  end

  defp add_result(base, nil), do: base
  defp add_result(base, result), do: Map.put(base, :result, render_result(result))

  defp add_strategy(base, simulation) do
    if Ecto.assoc_loaded?(simulation.strategy) && simulation.strategy do
      Map.put(base, :strategy, render_strategy_summary(simulation.strategy))
    else
      base
    end
  end

  defp add_target_draw(base, simulation) do
    if Ecto.assoc_loaded?(simulation.target_draw) && simulation.target_draw do
      Map.put(base, :target_draw, render_draw_summary(simulation.target_draw))
    else
      base
    end
  end

  defp render_result(result) do
    base = %{}

    base
    |> add_matched_numbers(result)
    |> add_failure_info(result)
    |> add_error_info(result)
    |> add_final_draw(result)
  end

  defp add_matched_numbers(base, %{matched_main: _} = result) do
    base
    |> Map.put(:matched_main, result.matched_main)
    |> Map.put(:matched_euro, result.matched_euro)
    |> Map.put(:attempts_count, result.attempts_count)
  end

  defp add_matched_numbers(base, _), do: base

  defp add_failure_info(base, %{reason: reason, limit_reached: limit_reached}) do
    base
    |> Map.put(:reason, reason)
    |> Map.put(:limit_reached, limit_reached)
  end

  defp add_failure_info(base, _), do: base

  defp add_error_info(base, %{error_message: error_message}) do
    Map.put(base, :error_message, error_message)
  end

  defp add_error_info(base, _), do: base

  defp add_final_draw(base, %{final_draw: final_draw}) do
    Map.put(base, :final_draw, %{
      main_numbers: final_draw.main_numbers,
      euro_numbers: final_draw.euro_numbers
    })
  end

  defp add_final_draw(base, _), do: base

  defp render_strategy_summary(strategy) do
    %{
      id: strategy.id,
      name: strategy.name,
      type: strategy.type
    }
  end

  defp render_draw_summary(draw) do
    %{
      id: draw.id,
      draw_date: draw.draw_date,
      game_type: draw.game_type
    }
  end
end
