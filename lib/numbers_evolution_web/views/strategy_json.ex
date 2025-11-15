defmodule NumbersEvolutionWeb.StrategyJSON do
  @moduledoc """
  JSON rendering for Strategy resources.
  """

  alias NumbersEvolution.Strategies.Strategy

  @doc """
  Renders a list of strategies.
  """
  def index(%{strategies: strategies, meta: meta}) do
    %{
      data: for(strategy <- strategies, do: data(strategy)),
      meta: meta
    }
  end

  @doc """
  Renders a single strategy.
  """
  def show(%{strategy: strategy}) do
    %{data: data(strategy)}
  end

  @doc """
  Renders a strategy with AI reasoning (for AI-generated strategies).
  """
  def show_with_reasoning(%{strategy: strategy}) do
    %{
      data:
        strategy
        |> data()
        |> Map.put(:reasoning, Map.get(strategy, :reasoning))
    }
  end

  @doc """
  Renders a strategy with component strategies (for mixed strategies).
  """
  def show_with_components(%{strategy: strategy}) do
    %{
      data:
        strategy
        |> data()
        |> Map.put(:component_strategies, Map.get(strategy, :component_strategies, []))
    }
  end

  defp data(%Strategy{} = strategy) do
    %{
      id: strategy.id,
      name: strategy.name,
      type: strategy.type,
      status: strategy.status,
      rules: render_rules(strategy.rules),
      performance_score: strategy.performance_score,
      simulations_count: Map.get(strategy, :simulations_count),
      ai_prompt: strategy.ai_prompt,
      inserted_at: strategy.inserted_at,
      updated_at: strategy.updated_at
    }
  end

  defp render_rules(nil), do: nil

  defp render_rules(rules) do
    %{
      main_numbers: %{
        ratio_even_odd: rules.main_numbers.ratio_even_odd,
        ratio_low_high: rules.main_numbers.ratio_low_high,
        preferred_hot: rules.main_numbers.preferred_hot,
        preferred_cold: rules.main_numbers.preferred_cold,
        weights: %{
          hot: rules.main_numbers.weights.hot,
          cold: rules.main_numbers.weights.cold,
          random: rules.main_numbers.weights.random
        }
      },
      euro_numbers: %{
        ratio_even_odd: rules.euro_numbers.ratio_even_odd,
        preferred: rules.euro_numbers.preferred,
        weights: %{
          hot: rules.euro_numbers.weights.hot,
          random: rules.euro_numbers.weights.random
        }
      }
    }
  end
end
