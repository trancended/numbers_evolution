defmodule NumbersEvolutionWeb.RankingJSON do
  @moduledoc """
  JSON rendering for Rankings.
  """

  @doc """
  Renders strategy rankings.
  """
  def strategies(%{rankings: rankings, meta: meta}) do
    %{
      data: for(ranking <- rankings, do: strategy_ranking(ranking)),
      meta: meta
    }
  end

  defp strategy_ranking(strategy) do
    %{
      rank: Map.get(strategy, :rank),
      strategy: %{
        id: strategy.id,
        name: strategy.name,
        type: strategy.type
      },
      performance_score: strategy.performance_score,
      simulations_count: Map.get(strategy, :simulations_count, 0),
      success_rate: Map.get(strategy, :success_rate),
      avg_duration: Map.get(strategy, :avg_duration)
    }
  end
end
