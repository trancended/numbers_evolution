defmodule NumbersEvolutionWeb.SimulationHelpers do
  @moduledoc """
  Shared helper functions for simulation-related operations.
  """

  alias NumbersEvolution.Games
  alias NumbersEvolution.Strategies.Generator

  @doc """
  Get pools for simulation, considering VIP modes and blacklists.
  """
  def get_pools_for_simulation(sim) do
    cond do
      vip2_with_blacklist?(sim) ->
        get_vip2_pools(sim)

      vip1_with_pool?(sim) ->
        get_vip1_pools(sim)

      true ->
        get_standard_pools(sim)
    end
  end

  @doc """
  Resolves the game config for a simulation from its target draw
  (falls back to the default game when the draw is not loaded).
  """
  def simulation_game(sim) do
    case sim do
      %{target_draw: %{game_type: game_type}} when is_binary(game_type) ->
        if Games.supported?(game_type), do: Games.get!(game_type), else: Games.default()

      _ ->
        Games.default()
    end
  end

  @doc """
  Build pools from available numbers (after blacklist or VIP pool filtering).
  """
  def build_pools_from_available(rules, main_available, euro_available) do
    main_available_set = MapSet.new(main_available)
    euro_available_set = MapSet.new(euro_available)

    # Main pools
    main_hot = filter_preferred_hot(rules, main_available)
    main_cold = filter_preferred_cold(rules, main_available)
    main_hot_cold_set = MapSet.new(main_hot ++ main_cold)
    main_random = get_random_main(main_available_set, main_hot_cold_set)

    # Euro pools
    euro_hot = filter_euro_hot(rules, euro_available)
    euro_hot_set = MapSet.new(euro_hot)
    euro_random = get_random_euro(euro_available_set, euro_hot_set)

    %{
      main_numbers: %{hot: main_hot, cold: main_cold, random: main_random},
      euro_numbers: %{hot: euro_hot, random: euro_random}
    }
  end

  # Private functions to reduce complexity

  defp vip2_with_blacklist?(sim) do
    sim.options && sim.options["vip2_blacklist"]
  end

  defp vip1_with_pool?(sim) do
    sim.options && sim.options["vip1_pool"]
  end

  defp get_vip2_pools(sim) do
    game = simulation_game(sim)
    blacklist = sim.options["vip2_blacklist"]
    main_blacklist = blacklist["main_blacklist"] || []
    euro_blacklist = blacklist["euro_blacklist"] || []
    main_available = Enum.reject(game.main.min..game.main.max, &(&1 in main_blacklist))

    euro_available =
      if game.bonus.count > 0 do
        Enum.reject(game.bonus.min..game.bonus.max, &(&1 in euro_blacklist))
      else
        []
      end

    build_pools_from_available(sim.strategy.rules, main_available, euro_available)
  end

  defp get_vip1_pools(sim) do
    vip1_pool = sim.options["vip1_pool"]
    main_pool = vip1_pool["main_pool"] || []
    euro_pool = vip1_pool["euro_pool"] || []

    build_pools_from_available(sim.strategy.rules, main_pool, euro_pool)
  end

  defp get_standard_pools(sim) do
    Generator.get_strategy_pools(sim.strategy, game: simulation_game(sim))
  end

  defp filter_preferred_hot(rules, main_available) do
    (rules.main_numbers.preferred_hot || [])
    |> Enum.filter(&(&1 in main_available))
  end

  defp filter_preferred_cold(rules, main_available) do
    (rules.main_numbers.preferred_cold || [])
    |> Enum.filter(&(&1 in main_available))
  end

  defp get_random_main(main_available_set, main_hot_cold_set) do
    main_available_set
    |> MapSet.difference(main_hot_cold_set)
    |> MapSet.to_list()
  end

  defp filter_euro_hot(rules, euro_available) do
    (rules.euro_numbers.preferred || [])
    |> Enum.filter(&(&1 in euro_available))
  end

  defp get_random_euro(euro_available_set, euro_hot_set) do
    euro_available_set
    |> MapSet.difference(euro_hot_set)
    |> MapSet.to_list()
  end
end
