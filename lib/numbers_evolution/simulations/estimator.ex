defmodule NumbersEvolution.Simulations.Estimator do
  @moduledoc """
  Turns the raw output of a Monte Carlo simulation run into a rigorous,
  interpretable result: per-tier hit rates with confidence intervals, an
  estimate of the expected attempts to jackpot (with CI, or a lower bound when
  no jackpot was observed), and monetary value metrics (EV / ROI) against an
  analytic random-ticket baseline.

  The canonical input is a **match histogram** `%{{main_matches, euro_matches} => count}`
  over `n` attempts. From it we derive both:

  - **cumulative tier rates** — matching the engine's `PrizeTiersTracker` counting
    (a 5+2 hit also counts toward 5+1, 4+2, ...); the right notion for
    "chance a ticket wins *at least* tier k".
  - **exact tier rates** — each attempt wins exactly one (best) prize; the right
    notion for **expected value**, so tiers are not double-counted.

  All functions are pure and DB-free. Confidence intervals use
  `NumbersEvolution.Statistics.wilson_interval/3` (robust for rare tiers).
  """

  alias NumbersEvolution.{Analytics, Games, Statistics}

  @type histogram :: %{{non_neg_integer(), non_neg_integer()} => non_neg_integer()}

  @typedoc "Full estimation result. See module doc."
  @type result :: %{
          n: non_neg_integer(),
          tier_rates: %{pos_integer() => map()},
          exact_tier_rates: %{pos_integer() => float()},
          attempts_to_jackpot: map(),
          expected_value: float(),
          roi: float(),
          ticket_cost: float(),
          baseline: map(),
          ev_delta: float()
        }

  @doc """
  Full estimation from a match `histogram` over `n` attempts for `game`.
  """
  @spec estimate(histogram(), non_neg_integer(), String.t() | map()) :: result()
  def estimate(histogram, n, game \\ Games.default_id()) do
    game = Games.get!(game)
    exact_rates = exact_tier_rates(histogram, n, game)
    ev = expected_value(exact_rates, game)
    baseline = baseline(game)
    cost = game.ticket_cost

    %{
      n: n,
      tier_rates: cumulative_tier_rates(histogram, n, game),
      exact_tier_rates: exact_rates,
      attempts_to_jackpot: attempts_to_jackpot(histogram, n, game),
      expected_value: ev,
      roi: safe_div(ev, cost),
      ticket_cost: cost,
      baseline: baseline,
      ev_delta: ev - baseline.expected_value
    }
  end

  @doc """
  Cumulative per-tier rate + Wilson CI, reproducing the engine's tier counting.

  Returns `%{tier => %{count: c, rate: r, ci_low: lo, ci_high: hi}}`.
  """
  @spec cumulative_tier_rates(histogram(), non_neg_integer(), map()) :: %{pos_integer() => map()}
  def cumulative_tier_rates(histogram, n, game) do
    Map.new(game.prize_tiers, fn {{mk, ek}, tier} ->
      count = cumulative_count(histogram, mk, ek)
      {_p, lo, hi} = Statistics.wilson_interval(count, max(n, 1))
      {tier, %{count: count, rate: safe_div(count, n), ci_low: lo, ci_high: hi}}
    end)
  end

  @doc """
  Exact per-tier rate: each attempt is credited to its single best tier only.
  Suitable for expected-value computation.
  """
  @spec exact_tier_rates(histogram(), non_neg_integer(), map()) :: %{pos_integer() => float()}
  def exact_tier_rates(histogram, n, game) do
    histogram
    |> Enum.reduce(%{}, fn {{m, e}, count}, acc ->
      case exact_tier(game, m, e) do
        nil -> acc
        tier -> Map.update(acc, tier, count, &(&1 + count))
      end
    end)
    |> Map.new(fn {tier, count} -> {tier, safe_div(count, n)} end)
  end

  @doc """
  Expected value per ticket (PLN): `sum(exact_rate_tier * payout_tier) - ticket_cost`.
  """
  @spec expected_value(%{pos_integer() => float()}, map()) :: float()
  def expected_value(exact_rates, game) do
    gross =
      Enum.reduce(exact_rates, 0.0, fn {tier, rate}, acc ->
        acc + rate * Map.get(game.payouts, tier, 0)
      end)

    gross - game.ticket_cost
  end

  @doc """
  Per-tier rate + Wilson CI directly from the engine's cumulative tier counts
  (`%{tier_number => count}`), for enriching a finished run without a histogram.
  """
  @spec tier_stats_from_counts(%{pos_integer() => non_neg_integer()}, non_neg_integer(), map()) ::
          %{pos_integer() => map()}
  def tier_stats_from_counts(counts, n, game) do
    Map.new(Map.values(game.prize_tiers), fn tier ->
      count = Map.get(counts, tier, 0)
      {_p, lo, hi} = Statistics.wilson_interval(count, max(n, 1))
      {tier, %{count: count, rate: safe_div(count, n), ci_low: lo, ci_high: hi}}
    end)
  end

  @doc """
  Estimated attempts to jackpot from a raw jackpot count over `n` attempts
  (same shape as `attempts_to_jackpot/3`).
  """
  @spec attempts_from_jackpot_count(non_neg_integer(), non_neg_integer()) :: map()
  def attempts_from_jackpot_count(jackpot_count, n), do: jackpot_estimate(jackpot_count, n)

  @doc """
  Estimated attempts to jackpot with a confidence interval.

  When at least one jackpot was observed, uses its Wilson interval to invert the
  rate into attempts. When none was observed, returns a **lower bound** from the
  rule of three (`n / 3`) instead of a misleading point estimate.
  """
  @spec attempts_to_jackpot(histogram(), non_neg_integer(), map()) :: map()
  def attempts_to_jackpot(histogram, n, game) do
    {mk, ek} = jackpot_key(game)
    hits = cumulative_count(histogram, mk, ek)
    jackpot_estimate(hits, n)
  end

  defp jackpot_estimate(0, n) when n > 0 do
    %{point: nil, low: n / 3.0, high: :infinity, observed: 0, note: :zero_events_lower_bound}
  end

  defp jackpot_estimate(0, _n) do
    %{point: nil, low: nil, high: :infinity, observed: 0, note: :no_data}
  end

  defp jackpot_estimate(hits, n) do
    {p, lo, hi} = Statistics.wilson_interval(hits, n)
    %{point: 1.0 / p, low: inv_or_inf(hi), high: inv_or_inf(lo), observed: hits, note: :estimated}
  end

  @doc """
  Analytic metrics for a purely random ticket (no strategy), for the given game.

  Every strategy result is presented as a delta against this baseline, so an
  apparent "edge" that merely tracks the random baseline is exposed as noise.
  """
  @spec baseline(String.t() | map()) :: map()
  def baseline(game) do
    game = Games.get!(game)
    probs = baseline_match_probs(game)
    exact_rates = probs_to_exact_rates(probs, game)
    {mk, ek} = jackpot_key(game)
    jackpot_p = Map.get(probs, {mk, ek}, 0.0)

    %{
      exact_tier_rates: exact_rates,
      expected_value: expected_value(exact_rates, game),
      attempts_to_jackpot_point: inv_or_inf(jackpot_p)
    }
  end

  @doc """
  Exact analytic joint probability `%{{m, e} => p}` of matching `m` main and
  `e` euro numbers with a single random ticket against a fixed draw
  (hypergeometric in each component).
  """
  @spec baseline_match_probs(map()) :: %{{non_neg_integer(), non_neg_integer()} => float()}
  def baseline_match_probs(game) do
    main_probs = component_probs(game.main.max - game.main.min + 1, game.main.count)
    euro_probs = euro_component_probs(game)

    for {m, pm} <- main_probs, {e, pe} <- euro_probs, into: %{} do
      {{m, e}, pm * pe}
    end
  end

  # Hypergeometric: probability of exactly `matches` shared numbers when both the
  # draw and the ticket pick `draw` numbers from a population of `pop`.
  defp component_probs(pop, draw) do
    denom = Analytics.comb(pop, draw)

    Map.new(0..draw, fn matches ->
      favourable = Analytics.comb(draw, matches) * Analytics.comb(pop - draw, draw - matches)
      {matches, favourable / denom}
    end)
  end

  defp euro_component_probs(%{bonus: %{count: 0}}), do: %{0 => 1.0}

  defp euro_component_probs(game) do
    component_probs(game.bonus.max - game.bonus.min + 1, game.bonus.count)
  end

  defp probs_to_exact_rates(probs, game) do
    Enum.reduce(probs, %{}, fn {{m, e}, p}, acc ->
      case exact_tier(game, m, e) do
        nil -> acc
        tier -> Map.update(acc, tier, p, &(&1 + p))
      end
    end)
  end

  @doc """
  The best (highest-value, i.e. lowest tier number) prize tier a result of
  `m` main and `e` euro matches qualifies for, or `nil` for no prize.
  """
  @spec exact_tier(map(), non_neg_integer(), non_neg_integer()) :: pos_integer() | nil
  def exact_tier(game, m, e) do
    game.prize_tiers
    |> Enum.filter(fn {{mk, ek}, _tier} -> mk <= m and ek <= e end)
    |> Enum.map(fn {_key, tier} -> tier end)
    |> case do
      [] -> nil
      tiers -> Enum.min(tiers)
    end
  end

  # Cumulative count: every histogram bucket that meets or exceeds the tier
  # threshold in both components (mirrors PrizeTiersTracker's counting).
  defp cumulative_count(histogram, mk, ek) do
    Enum.reduce(histogram, 0, fn {{m, e}, count}, acc ->
      if m >= mk and e >= ek, do: acc + count, else: acc
    end)
  end

  defp jackpot_key(game) do
    {key, _tier} = Enum.find(game.prize_tiers, fn {_key, tier} -> tier == 1 end)
    key
  end

  defp inv_or_inf(p) when is_number(p) and p > 0.0, do: 1.0 / p
  defp inv_or_inf(_p), do: :infinity

  defp safe_div(_num, 0), do: 0.0
  defp safe_div(_num, +0.0), do: 0.0
  defp safe_div(num, denom), do: num / denom
end
