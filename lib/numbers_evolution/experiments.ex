defmodule NumbersEvolution.Experiments do
  @moduledoc """
  Backtesting: run a candidate generator against a *set* of draws and aggregate
  the results. This is the "value regime" of the plan — instead of a single
  look-ahead "what if", it answers "how would this generator have performed
  across many historical draws", with the spread across draws as a robustness
  signal.

  For each target draw it draws `attempts` candidate combinations, builds a match
  histogram, and runs the `Estimator` (EV, ROI, per-tier rates, attempts to
  jackpot). It then aggregates per-draw EVs into a mean, a stddev-based
  robustness score, and EV percentiles, and compares against the analytic random
  baseline.

  Pure and DB-free: the generator is an injected `(-> combo)` function, so any
  strategy, `Algorithm` engine or raw sampler can be backtested, and results are
  reproducible via `opts[:seed]`.
  """

  alias NumbersEvolution.{Games, Statistics}
  alias NumbersEvolution.Simulations.Estimator

  @type combo :: %{main: [pos_integer()], euro: [pos_integer()]}

  @doc """
  Backtest `gen_fun` (a zero-arity function returning a `combo`) across `draws`.

  `draws` entries may be `%{main: [...], euro: [...]}`, a draw with
  `numbers.main_numbers/euro_numbers`, or a `%{numbers: ...}` map. `opts`:
  `:attempts` per draw (default 100_000), `:seed`.

  Returns `%{per_draw: [...], summary: %{...}}`.
  """
  @spec backtest((-> combo()), [term()], String.t() | map(), keyword()) :: map()
  def backtest(gen_fun, draws, game \\ Games.default_id(), opts \\ []) do
    game = Games.get!(game)
    attempts = Keyword.get(opts, :attempts, 100_000)
    if opts[:seed], do: :rand.seed(:exsss, opts[:seed])

    per_draw = Enum.map(draws, fn draw -> backtest_one(gen_fun, draw, game, attempts) end)
    %{per_draw: per_draw, summary: summarize(per_draw, game)}
  end

  @doc """
  A uniform random combo generator for `game` — the baseline any strategy must
  beat, and a way to validate backtests (its EV should track the analytic baseline).
  """
  @spec random_generator(String.t() | map()) :: (-> combo())
  def random_generator(game) do
    game = Games.get!(game)
    main = Enum.to_list(game.main.min..game.main.max)
    euro = euro_pool(game)

    fn ->
      %{
        main: Enum.take_random(main, game.main.count),
        euro: Enum.take_random(euro, game.bonus.count)
      }
    end
  end

  defp backtest_one(gen_fun, draw, game, attempts) do
    target = normalize_target(draw)
    histogram = build_histogram(gen_fun, target, attempts)
    estimate = Estimator.estimate(histogram, attempts, game)

    %{
      target: target,
      attempts: attempts,
      expected_value: estimate.expected_value,
      roi: estimate.roi,
      ev_delta: estimate.ev_delta,
      attempts_to_jackpot: estimate.attempts_to_jackpot
    }
  end

  # Sample `attempts` combos and tally exact (main, euro) match counts.
  defp build_histogram(gen_fun, target, attempts) do
    main_set = MapSet.new(target.main)
    euro_set = MapSet.new(target.euro)

    Enum.reduce(1..attempts, %{}, fn _i, acc ->
      combo = gen_fun.()
      key = {count_in(combo.main, main_set), count_in(combo.euro, euro_set)}
      Map.update(acc, key, 1, &(&1 + 1))
    end)
  end

  defp summarize([], game), do: %{draws: 0, baseline_ev: Estimator.baseline(game).expected_value}

  defp summarize(per_draw, game) do
    evs = Enum.map(per_draw, & &1.expected_value)
    rois = Enum.map(per_draw, & &1.roi)
    ev_stddev = Statistics.stddev(evs) || 0.0
    baseline_ev = Estimator.baseline(game).expected_value

    %{
      draws: length(per_draw),
      ev_mean: Statistics.mean(evs),
      ev_stddev: ev_stddev,
      ev_p10: Statistics.percentile(evs, 0.1),
      ev_p50: Statistics.percentile(evs, 0.5),
      ev_p90: Statistics.percentile(evs, 0.9),
      roi_mean: Statistics.mean(rois),
      robustness: 1.0 / (1.0 + ev_stddev),
      baseline_ev: baseline_ev,
      ev_delta_mean: Statistics.mean(evs) - baseline_ev
    }
  end

  @doc """
  Splits `draws` into `{train, test}` for out-of-sample validation: optimize a
  strategy on `train`, then confirm the edge holds on `test`.
  """
  @spec train_test_split([term()], float()) :: {[term()], [term()]}
  def train_test_split(draws, train_fraction \\ 0.7) do
    cut = round(length(draws) * train_fraction)
    Enum.split(draws, cut)
  end

  @doc "Extracts a `%{main:, euro:}` target from the supported draw shapes."
  @spec normalize_target(term()) :: combo()
  def normalize_target(%{main: main, euro: euro}), do: %{main: main, euro: euro}

  def normalize_target(%{numbers: %{main_numbers: main} = numbers}) do
    %{main: main, euro: Map.get(numbers, :euro_numbers, [])}
  end

  defp count_in(numbers, set), do: Enum.count(numbers, &MapSet.member?(set, &1))

  defp euro_pool(%{bonus: %{count: 0}}), do: []
  defp euro_pool(game), do: Enum.to_list(game.bonus.min..game.bonus.max)
end
