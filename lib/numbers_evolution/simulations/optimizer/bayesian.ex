defmodule NumbersEvolution.Simulations.Optimizer.Bayesian do
  @moduledoc """
  ALG-5 — Bayesian optimization via a Tree-structured Parzen Estimator (TPE).

  The most sample-efficient optimizer in the library: it models the objective
  from past evaluations and proposes the next point where improvement is most
  likely, so it needs far fewer (expensive) probe/backtest evaluations than a
  genetic search. Ideal as the top-level orchestrator that hands promising
  regions to `NelderMead` for local refinement.

  TPE splits observations into "good" (best `gamma` quantile) and "bad", models
  each group with an independent per-dimension Gaussian KDE, and picks the
  candidate maximizing the density ratio `l(x) / g(x)`. Implements
  `NumbersEvolution.Simulations.Search`.

  `opts`:
  - `:bounds` — required, `[{lo, hi}]`
  - `:max_iter` — total objective evaluations (default 80)
  - `:startup` — random evaluations before modelling (default 12)
  - `:gamma` — good-quantile fraction (default 0.25)
  - `:candidates` — proposals scored per iteration (default 24)
  - `:bandwidth` — KDE bandwidth as a fraction of each range (default 0.1)
  - `:seed` — reproducible search
  """

  @behaviour NumbersEvolution.Simulations.Search

  @impl true
  def minimize(objective, opts) do
    bounds = Keyword.fetch!(opts, :bounds)
    max_iter = Keyword.get(opts, :max_iter, 80)
    startup = Keyword.get(opts, :startup, 12)
    if opts[:seed], do: :rand.seed(:exsss, opts[:seed])

    history = for _ <- 1..startup, do: eval(objective, random_point(bounds))
    history = optimize(objective, history, bounds, opts, max_iter)

    {x, y} = Enum.min_by(history, fn {_x, y} -> y end)
    %{params: x, score: y, iterations: length(history), converged: true}
  end

  defp optimize(objective, history, bounds, opts, max_iter) do
    if length(history) >= max_iter do
      history
    else
      candidate = propose(history, bounds, opts)
      optimize(objective, [eval(objective, candidate) | history], bounds, opts, max_iter)
    end
  end

  # Split into good/bad by objective quantile, then pick the candidate with the
  # highest good/bad density ratio.
  defp propose(history, bounds, opts) do
    gamma = Keyword.get(opts, :gamma, 0.25)
    n_candidates = Keyword.get(opts, :candidates, 24)
    bw = bandwidths(bounds, Keyword.get(opts, :bandwidth, 0.1))

    sorted = history |> Enum.sort_by(fn {_x, y} -> y end) |> Enum.map(fn {x, _y} -> x end)
    n_good = max(1, round(gamma * length(sorted)))
    {good, bad} = Enum.split(sorted, n_good)

    1..n_candidates
    |> Enum.map(fn _ -> sample_near(good, bw, bounds) end)
    |> Enum.max_by(fn cand -> score(cand, good, bad, bw) end)
  end

  # log l(x) - log g(x); a bad-empty group means every candidate improves, so
  # fall back to maximizing l(x) alone.
  defp score(x, good, [], bw), do: log_density(x, good, bw)
  defp score(x, good, bad, bw), do: log_density(x, good, bw) - log_density(x, bad, bw)

  defp log_density(x, points, bw) do
    n = length(points)

    x
    |> Enum.with_index()
    |> Enum.reduce(0.0, fn {xd, d}, acc ->
      acc + :math.log(dim_density(xd, points, d, Enum.at(bw, d), n))
    end)
  end

  defp dim_density(xd, points, d, sigma, n) do
    sum = Enum.reduce(points, 0.0, fn p, acc -> acc + gaussian_pdf(xd, Enum.at(p, d), sigma) end)
    max(sum / n, 1.0e-300)
  end

  defp gaussian_pdf(x, mu, sigma) do
    z = (x - mu) / sigma
    :math.exp(-0.5 * z * z) / (sigma * :math.sqrt(2.0 * :math.pi()))
  end

  # Draw a candidate by jittering a random good point (Parzen sampling).
  defp sample_near(good, bw, bounds) do
    base = Enum.random(good)

    base
    |> Enum.zip(bw)
    |> Enum.zip(bounds)
    |> Enum.map(fn {{coord, sigma}, {lo, hi}} ->
      (coord + gaussian() * sigma) |> max(lo) |> min(hi)
    end)
  end

  defp bandwidths(bounds, frac) do
    Enum.map(bounds, fn {lo, hi} -> max((hi - lo) * frac, 1.0e-9) end)
  end

  defp random_point(bounds) do
    Enum.map(bounds, fn {lo, hi} -> lo + :rand.uniform() * (hi - lo) end)
  end

  defp eval(objective, x), do: {x, objective.(x) * 1.0}

  defp gaussian do
    u1 = max(:rand.uniform(), 1.0e-12)
    u2 = :rand.uniform()
    :math.sqrt(-2.0 * :math.log(u1)) * :math.cos(2.0 * :math.pi() * u2)
  end
end
