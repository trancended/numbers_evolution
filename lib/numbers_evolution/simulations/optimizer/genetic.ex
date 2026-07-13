defmodule NumbersEvolution.Simulations.Optimizer.Genetic do
  @moduledoc """
  ALG-3 — Genetic strategy search (the literal "Numbers Evolution").

  A real-coded genetic algorithm that **minimizes** an objective over a bounded
  vector genome via tournament selection, blend (arithmetic) crossover, Gaussian
  mutation and elitism. Encode a strategy's tunable rules (ratios, weights,
  blacklist size) as the genome and the algorithm *discovers* strategies rather
  than a human hand-tuning them.

  Implements `NumbersEvolution.Simulations.Search`. Reproducible via `opts[:seed]`.

  `opts`:
  - `:bounds` — required, `[{lo, hi}]`, one pair per genome dimension
  - `:population` (default 40), `:generations` (default 60)
  - `:elite` (default 2), `:tournament` (default 3)
  - `:mutation_rate` (default 0.2), `:mutation_scale` (default 0.1 of each range)
  - `:seed` — `{int, int, int}` for `:rand.seed(:exsss, seed)`
  """

  @behaviour NumbersEvolution.Simulations.Search

  @impl true
  def minimize(objective, opts) do
    bounds = Keyword.fetch!(opts, :bounds)
    pop_size = Keyword.get(opts, :population, 40)
    generations = Keyword.get(opts, :generations, 60)
    maybe_seed(opts[:seed])

    initial = for _ <- 1..pop_size, do: random_genome(bounds)
    scored = evaluate(initial, objective)

    final =
      Enum.reduce(1..generations, scored, fn _gen, current ->
        current |> next_generation(objective, bounds, opts) |> merge_elite(current, opts)
      end)

    {best, score} = Enum.min_by(final, fn {_g, s} -> s end)
    %{params: best, score: score, iterations: generations, converged: true}
  end

  defp next_generation(scored, objective, bounds, opts) do
    pop_size = Keyword.get(opts, :population, 40)
    children = for _ <- 1..pop_size, do: breed(scored, bounds, opts)
    evaluate(children, objective)
  end

  # Elitism: keep the best individuals from the previous generation so progress
  # is monotone, then trim back to the population size.
  defp merge_elite(children, previous, opts) do
    elite = Keyword.get(opts, :elite, 2)
    pop_size = Keyword.get(opts, :population, 40)
    kept = previous |> Enum.sort_by(fn {_g, s} -> s end) |> Enum.take(elite)
    (kept ++ children) |> Enum.sort_by(fn {_g, s} -> s end) |> Enum.take(pop_size)
  end

  defp breed(scored, bounds, opts) do
    parent_a = tournament(scored, opts)
    parent_b = tournament(scored, opts)
    parent_a |> crossover(parent_b) |> mutate(bounds, opts) |> clamp(bounds)
  end

  defp evaluate(genomes, objective) do
    Enum.map(genomes, fn g -> {g, objective.(g) * 1.0} end)
  end

  defp tournament(scored, opts) do
    k = Keyword.get(opts, :tournament, 3)
    {genome, _score} = scored |> Enum.take_random(k) |> Enum.min_by(fn {_g, s} -> s end)
    genome
  end

  # Arithmetic (blend) crossover with a per-gene random weight.
  defp crossover(a, b) do
    Enum.zip_with(a, b, fn ga, gb ->
      w = :rand.uniform()
      w * ga + (1 - w) * gb
    end)
  end

  defp mutate(genome, bounds, opts) do
    rate = Keyword.get(opts, :mutation_rate, 0.2)
    scale = Keyword.get(opts, :mutation_scale, 0.1)

    Enum.zip_with(genome, bounds, fn gene, {lo, hi} ->
      if :rand.uniform() < rate do
        gene + gaussian() * scale * (hi - lo)
      else
        gene
      end
    end)
  end

  defp clamp(genome, bounds) do
    Enum.zip_with(genome, bounds, fn gene, {lo, hi} -> gene |> max(lo) |> min(hi) end)
  end

  defp random_genome(bounds) do
    Enum.map(bounds, fn {lo, hi} -> lo + :rand.uniform() * (hi - lo) end)
  end

  # Box-Muller standard normal.
  defp gaussian do
    u1 = max(:rand.uniform(), 1.0e-12)
    u2 = :rand.uniform()
    :math.sqrt(-2.0 * :math.log(u1)) * :math.cos(2.0 * :math.pi() * u2)
  end

  defp maybe_seed(nil), do: :ok
  defp maybe_seed(seed), do: :rand.seed(:exsss, seed)
end
