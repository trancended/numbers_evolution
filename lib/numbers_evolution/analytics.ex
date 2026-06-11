defmodule NumbersEvolution.Analytics do
  @moduledoc """
  Strategy effectiveness analytics.

  Aggregates completed simulations per strategy and generation mode, comparing
  the theoretical combination search space against actually observed attempts.
  This makes it visible *why* auto-blacklist (VIP2/VIP3) strategies succeed:
  they shrink the search space by orders of magnitude, while plain rule-based
  strategies barely reduce it at all.
  """

  import Ecto.Query, warn: false

  alias NumbersEvolution.Accounts.User
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Simulations.Simulation

  @completed_statuses ["success", "max_attempts_reached", "timeout"]

  # C(50,5) * C(12,2)
  @full_search_space 139_838_160

  @doc """
  Returns per-strategy/per-mode effectiveness stats for a user's completed
  simulations, sorted by median attempts (best first).

  Each entry contains:
  - `:strategy` - the strategy struct
  - `:mode` - `:standard | :half_random | :vip1 | :auto_blacklist`
  - `:simulations_count`, `:success_count`, `:success_rate`
  - `:min_attempts`, `:median_attempts`, `:avg_attempts`, `:max_attempts` (successes only)
  - `:avg_duration_seconds`, `:attempts_per_second`
  - `:search_space` - theoretical number of combinations for the mode
  - `:expected_vs_actual` - median attempts / search space (for successes)
  - `:tiers_per_100k` - prize tier hits normalized per 100k attempts
  """
  @spec strategy_stats(User.t()) :: [map()]
  def strategy_stats(%User{id: user_id}) do
    from(s in Simulation,
      where: s.user_id == ^user_id and s.status in ^@completed_statuses,
      preload: [:strategy]
    )
    |> Repo.all()
    |> Enum.filter(& &1.strategy)
    |> Enum.group_by(fn sim -> {sim.strategy.id, simulation_mode(sim.options || %{})} end)
    |> Enum.map(fn {{_strategy_id, mode}, sims} -> summarize_group(mode, sims) end)
    |> Enum.sort_by(&(&1.median_attempts || @full_search_space * 10))
  end

  @doc """
  Aggregates a list of completed simulations (same strategy + mode) into stats.

  Public to keep it testable without the database.
  """
  @spec summarize_group(atom(), [Simulation.t()]) :: map()
  def summarize_group(mode, [first | _] = sims) do
    successes = Enum.filter(sims, &(&1.status == "success"))
    success_attempts = successes |> Enum.map(& &1.attempts_count) |> Enum.sort()

    total_attempts = sims |> Enum.map(&(&1.attempts_count || 0)) |> Enum.sum()
    total_duration = sims |> Enum.map(&(&1.duration_seconds || 0.0)) |> Enum.sum()

    search_space = search_space_for_options(first.options || %{})
    median = median(success_attempts)

    %{
      strategy: first.strategy,
      mode: mode,
      simulations_count: length(sims),
      success_count: length(successes),
      success_rate: length(successes) / length(sims),
      min_attempts: List.first(success_attempts),
      median_attempts: median,
      avg_attempts: avg(success_attempts),
      max_attempts: List.last(success_attempts),
      avg_duration_seconds: total_duration / length(sims),
      attempts_per_second: if(total_duration > 0, do: total_attempts / total_duration),
      search_space: search_space,
      expected_vs_actual: if(median && search_space > 0, do: median / search_space),
      tiers_per_100k: tiers_per_100k(sims, total_attempts)
    }
  end

  @doc """
  Theoretical search space (number of distinct combinations) the generator
  draws from, given simulation options.

  - auto-blacklist (VIP2/VIP3): C(50-k, 5) * C(12-j, 2)
  - VIP1: fixed half pool, C(25,5) * C(6,2)
  - standard / half-random: full C(50,5) * C(12,2) (half-random re-rolls its
    pool every attempt, so every combination stays reachable)
  """
  @spec search_space_for_options(map()) :: pos_integer()
  def search_space_for_options(options) do
    cond do
      blacklist = options["vip2_blacklist"] ->
        main_size = blacklist["main_size"] || length(blacklist["main_blacklist"] || [])
        euro_size = blacklist["euro_size"] || length(blacklist["euro_blacklist"] || [])
        comb(50 - main_size, 5) * comb(12 - euro_size, 2)

      options["vip1_mode"] ->
        comb(25, 5) * comb(6, 2)

      true ->
        @full_search_space
    end
  end

  @doc """
  Detects the generation mode from simulation options.
  """
  @spec simulation_mode(map()) :: :auto_blacklist | :vip1 | :half_random | :standard
  def simulation_mode(options) do
    cond do
      options["vip2_blacklist"] -> :auto_blacklist
      options["vip1_mode"] -> :vip1
      options["half_random_mode"] -> :half_random
      true -> :standard
    end
  end

  @doc """
  Binomial coefficient C(n, k).
  """
  @spec comb(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def comb(n, k) when k > n, do: 0
  def comb(_n, 0), do: 1

  def comb(n, k) do
    Enum.reduce(1..k, 1, fn i, acc -> div(acc * (n - k + i), i) end)
  end

  @doc """
  Returns the full Eurojackpot search space C(50,5) * C(12,2).
  """
  @spec full_search_space() :: pos_integer()
  def full_search_space, do: @full_search_space

  # Sums result.prize_tiers maps across simulations, normalized per 100k attempts
  defp tiers_per_100k(_sims, 0), do: %{}

  defp tiers_per_100k(sims, total_attempts) do
    sims
    |> Enum.flat_map(fn sim ->
      case sim.result do
        %{prize_tiers: tiers} when is_map(tiers) -> Map.to_list(tiers)
        _ -> []
      end
    end)
    |> Enum.reduce(%{}, fn {tier, count}, acc ->
      tier = if is_binary(tier), do: String.to_integer(tier), else: tier
      Map.update(acc, tier, count, &(&1 + count))
    end)
    |> Map.new(fn {tier, count} -> {tier, count * 100_000 / total_attempts} end)
  end

  defp median([]), do: nil

  defp median(sorted_list) do
    count = length(sorted_list)

    if rem(count, 2) == 0 do
      mid1 = Enum.at(sorted_list, div(count, 2) - 1)
      mid2 = Enum.at(sorted_list, div(count, 2))
      (mid1 + mid2) / 2.0
    else
      Enum.at(sorted_list, div(count, 2)) * 1.0
    end
  end

  defp avg([]), do: nil
  defp avg(list), do: Enum.sum(list) / length(list)
end
