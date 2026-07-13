defmodule NumbersEvolution.Statistics do
  @moduledoc """
  Pure statistical helpers used by the simulation Estimator, Optimizer and
  Analytics layers.

  Everything here is side-effect free and DB-free so it is trivially testable
  and safe to call from hot paths. Functions favour numerical robustness over
  raw speed (sample sizes are small: prize-tier counts, per-run attempt lists).

  Provides:
  - descriptive stats: `mean/1`, `variance/1`, `stddev/1`, `percentile/2`, `median/1`
  - proportion confidence intervals: `wilson_interval/3` (robust for tiny p),
    `rule_of_three/1` (upper bound when zero events observed)
  - hypothesis testing: `two_proportion_z/4`, `normal_cdf/1`
  - resampling: `bootstrap_ci/4`
  """

  @z95 1.959963984540054

  @typedoc "A {point_estimate, lower_bound, upper_bound} confidence triple."
  @type interval :: {float(), float(), float()}

  ## Descriptive statistics

  @doc "Arithmetic mean, or `nil` for an empty list."
  @spec mean([number()]) :: float() | nil
  def mean([]), do: nil
  def mean(list), do: Enum.sum(list) / length(list)

  @doc """
  Sample variance (Bessel-corrected, n-1). Returns `0.0` for a single element
  and `nil` for an empty list.
  """
  @spec variance([number()]) :: float() | nil
  def variance([]), do: nil
  def variance([_single]), do: 0.0

  def variance(list) do
    m = mean(list)
    n = length(list)
    Enum.reduce(list, 0.0, fn x, acc -> acc + (x - m) * (x - m) end) / (n - 1)
  end

  @doc "Sample standard deviation (square root of `variance/1`)."
  @spec stddev([number()]) :: float() | nil
  def stddev([]), do: nil

  def stddev(list) do
    :math.sqrt(variance(list))
  end

  @doc "Median via `percentile/2` at 0.5."
  @spec median([number()]) :: float() | nil
  def median(list), do: percentile(list, 0.5)

  @doc """
  Linear-interpolation percentile for `p` in `0.0..1.0`.

  The list does not need to be pre-sorted. Returns `nil` for an empty list.

      iex> NumbersEvolution.Statistics.percentile([1, 2, 3, 4], 0.5)
      2.5
  """
  @spec percentile([number()], float()) :: float() | nil
  def percentile([], _p), do: nil
  def percentile(list, p) when p <= 0.0, do: list |> Enum.min() |> :erlang.float()
  def percentile(list, p) when p >= 1.0, do: list |> Enum.max() |> :erlang.float()

  def percentile(list, p) do
    sorted = Enum.sort(list)
    rank = p * (length(sorted) - 1)
    lower_idx = trunc(rank)
    frac = rank - lower_idx
    lower = Enum.at(sorted, lower_idx)
    upper = Enum.at(sorted, lower_idx + 1, lower)
    lower + (upper - lower) * frac
  end

  ## Proportion confidence intervals

  @doc """
  Wilson score interval for a binomial proportion `successes / trials`.

  Robust when `p` is close to 0 or 1 (unlike the normal approximation), which is
  exactly the regime of rare prize tiers. `z` defaults to the 95% quantile.

  Returns `{p_hat, low, high}` with bounds clamped to `0.0..1.0`. For `trials == 0`
  returns `{0.0, 0.0, 1.0}` (maximal ignorance).
  """
  @spec wilson_interval(non_neg_integer(), non_neg_integer(), float()) :: interval()
  def wilson_interval(successes, trials, z \\ @z95)
  def wilson_interval(_successes, 0, _z), do: {0.0, 0.0, 1.0}

  def wilson_interval(successes, trials, z) do
    n = trials * 1.0
    p_hat = successes / n
    z2 = z * z
    denom = 1 + z2 / n
    center = (p_hat + z2 / (2 * n)) / denom
    margin = z / denom * :math.sqrt(p_hat * (1 - p_hat) / n + z2 / (4 * n * n))
    {p_hat, clamp01(center - margin), clamp01(center + margin)}
  end

  @doc """
  Rule of three: an approximate 95% upper bound on the true probability when
  `0` events were observed in `n` trials, `3 / n`.

  Used for jackpot probability in standard mode, where a run of a million
  attempts routinely observes zero jackpots yet still bounds the rate.
  """
  @spec rule_of_three(pos_integer()) :: float()
  def rule_of_three(n) when n > 0, do: 3.0 / n

  ## Hypothesis testing

  @doc """
  Two-sided two-proportion z-test comparing `x1/n1` against `x2/n2`.

  Returns `{z, p_value}` where `p_value` is the probability of observing a
  difference at least this extreme under the null hypothesis of equal
  proportions. A small `p_value` (e.g. < 0.05) means the strategies differ by
  more than sampling noise.
  """
  @spec two_proportion_z(non_neg_integer(), pos_integer(), non_neg_integer(), pos_integer()) ::
          {float(), float()}
  def two_proportion_z(x1, n1, x2, n2) do
    p1 = x1 / n1
    p2 = x2 / n2
    pooled = (x1 + x2) / (n1 + n2)
    se = :math.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
    two_proportion_result(p1 - p2, se)
  end

  defp two_proportion_result(_diff, se) when se == 0.0, do: {0.0, 1.0}

  defp two_proportion_result(diff, se) do
    z = diff / se
    p_value = 2 * (1 - normal_cdf(abs(z)))
    {z, p_value}
  end

  @doc """
  Standard normal CDF via the Abramowitz & Stegun 7.1.26 erf approximation
  (absolute error < 1.5e-7).
  """
  @spec normal_cdf(float()) :: float()
  def normal_cdf(x) do
    0.5 * (1.0 + erf(x / :math.sqrt(2.0)))
  end

  defp erf(x) do
    sign = if x < 0, do: -1.0, else: 1.0
    ax = abs(x)
    t = 1.0 / (1.0 + 0.3275911 * ax)

    poly =
      ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t +
         0.254829592) * t

    sign * (1.0 - poly * :math.exp(-ax * ax))
  end

  ## Resampling

  @doc """
  Percentile bootstrap confidence interval for a statistic over `samples`.

  Resamples with replacement `iterations` times, applies `stat_fun` to each
  resample, and returns `{point, low, high}` at the given confidence `level`
  (default 0.95). `point` is `stat_fun` on the original sample.

  Deterministic given the process RNG seed (see `Simulations` seeding), so
  bootstrap results are reproducible in single-threaded runs.
  """
  @spec bootstrap_ci([number()], ([number()] -> number()), pos_integer(), float()) ::
          interval() | nil
  def bootstrap_ci(samples, stat_fun, iterations \\ 2000, level \\ 0.95)
  def bootstrap_ci([], _stat_fun, _iterations, _level), do: nil

  def bootstrap_ci(samples, stat_fun, iterations, level) do
    n = length(samples)
    vec = List.to_tuple(samples)

    stats =
      Enum.map(1..iterations, fn _ ->
        resample = for _ <- 1..n, do: elem(vec, :rand.uniform(n) - 1)
        stat_fun.(resample)
      end)

    alpha = (1 - level) / 2
    {stat_fun.(samples) * 1.0, percentile(stats, alpha), percentile(stats, 1 - alpha)}
  end

  ## Helpers

  defp clamp01(x) when x < 0.0, do: 0.0
  defp clamp01(x) when x > 1.0, do: 1.0
  defp clamp01(x), do: x
end
