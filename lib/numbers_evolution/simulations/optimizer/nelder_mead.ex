defmodule NumbersEvolution.Simulations.Optimizer.NelderMead do
  @moduledoc """
  ALG-4 — Nelder–Mead downhill simplex.

  A derivative-free local optimizer that **minimizes** a smooth, low-dimensional
  objective faster than a genetic search — ideal as a *refinement* step after a
  global optimizer (GA/Bayesian) has located a promising region (see
  `Objective` / mixing pipeline).

  Implements `NumbersEvolution.Simulations.Search`.

  `opts`:
  - `:start` — initial point (defaults to the midpoint of `:bounds`)
  - `:bounds` — optional `[{lo, hi}]`; when given, vertices are clamped into range
  - `:step` — initial simplex edge as a fraction of each dimension (default 0.1)
  - `:max_iter` (default 200), `:tol` (default 1.0e-8)
  """

  @behaviour NumbersEvolution.Simulations.Search

  @alpha 1.0
  @gamma 2.0
  @rho 0.5
  @sigma 0.5

  @impl true
  def minimize(objective, opts) do
    start = start_point(opts)
    bounds = Keyword.get(opts, :bounds)
    max_iter = Keyword.get(opts, :max_iter, 200)
    tol = Keyword.get(opts, :tol, 1.0e-8)

    simplex = start |> build_simplex(opts) |> evaluate(objective, bounds)

    {final, iters} =
      Enum.reduce_while(1..max_iter, {simplex, 0}, fn i, {s, _} ->
        if converged?(s, tol),
          do: {:halt, {s, i}},
          else: {:cont, {iterate(s, objective, bounds), i}}
      end)

    {best, score} = Enum.min_by(final, fn {_v, s} -> s end)
    %{params: best, score: score, iterations: iters, converged: converged?(final, tol)}
  end

  # One Nelder–Mead step: reflect the worst vertex through the centroid of the
  # rest, then expand / contract / shrink depending on how good the reflection is.
  defp iterate(simplex, objective, bounds) do
    sorted = Enum.sort_by(simplex, fn {_v, s} -> s end)
    {_best_v, best_s} = hd(sorted)
    {worst_v, worst_s} = List.last(sorted)
    {_second_v, second_s} = Enum.at(sorted, length(sorted) - 2)

    centroid = centroid(sorted)
    {refl_v, refl_s} = eval_point(centroid, worst_v, @alpha, objective, bounds)

    cond do
      refl_s < best_s ->
        try_expand(sorted, centroid, worst_v, {refl_v, refl_s}, objective, bounds)

      refl_s < second_s ->
        replace_worst(sorted, {refl_v, refl_s})

      true ->
        contract_or_shrink(sorted, centroid, {worst_v, worst_s}, objective, bounds)
    end
  end

  defp try_expand(sorted, centroid, worst_v, reflection, objective, bounds) do
    {exp_v, exp_s} = eval_point(centroid, worst_v, @gamma, objective, bounds)
    {_refl_v, refl_s} = reflection

    if exp_s < refl_s,
      do: replace_worst(sorted, {exp_v, exp_s}),
      else: replace_worst(sorted, reflection)
  end

  defp contract_or_shrink(sorted, centroid, {worst_v, worst_s}, objective, bounds) do
    {con_v, con_s} = eval_point(centroid, worst_v, @rho, objective, bounds)

    if con_s < worst_s do
      replace_worst(sorted, {con_v, con_s})
    else
      shrink(sorted, objective, bounds)
    end
  end

  # point = centroid + coeff * (centroid - vertex); coeff selects reflect/expand/contract.
  defp eval_point(centroid, vertex, coeff, objective, bounds) do
    p = add(centroid, scale(sub(centroid, vertex), coeff)) |> clamp(bounds)
    {p, objective.(p) * 1.0}
  end

  defp replace_worst(sorted, new_vertex) do
    (Enum.drop(sorted, -1) ++ [new_vertex]) |> Enum.sort_by(fn {_v, s} -> s end)
  end

  # Shrink every vertex toward the current best.
  defp shrink([{best_v, _} = best | rest], objective, bounds) do
    shrunk =
      Enum.map(rest, fn {v, _s} ->
        nv = add(best_v, scale(sub(v, best_v), @sigma)) |> clamp(bounds)
        {nv, objective.(nv) * 1.0}
      end)

    [best | shrunk]
  end

  defp centroid(sorted) do
    vertices = sorted |> Enum.drop(-1) |> Enum.map(fn {v, _s} -> v end)
    n = length(vertices)
    vertices |> Enum.zip_with(&Enum.sum/1) |> Enum.map(&(&1 / n))
  end

  defp build_simplex(start, opts) do
    step = Keyword.get(opts, :step, 0.1)
    bounds = Keyword.get(opts, :bounds)

    offsets =
      start
      |> Enum.with_index()
      |> Enum.map(fn {_coord, i} -> perturb(start, i, step, bounds) end)

    [start | offsets]
  end

  defp perturb(point, index, step, bounds) do
    delta = dimension_step(bounds, index, step)
    List.update_at(point, index, &(&1 + delta))
  end

  defp dimension_step(nil, _index, step), do: max(step, 1.0e-6)

  defp dimension_step(bounds, index, step) do
    {lo, hi} = Enum.at(bounds, index)
    max((hi - lo) * step, 1.0e-6)
  end

  defp evaluate(vertices, objective, bounds) do
    Enum.map(vertices, fn v ->
      cv = clamp(v, bounds)
      {cv, objective.(cv) * 1.0}
    end)
  end

  defp converged?(simplex, tol) do
    scores = Enum.map(simplex, fn {_v, s} -> s end)
    Enum.max(scores) - Enum.min(scores) < tol
  end

  defp clamp(vertex, nil), do: vertex

  defp clamp(vertex, bounds) do
    Enum.zip_with(vertex, bounds, fn c, {lo, hi} -> c |> max(lo) |> min(hi) end)
  end

  defp start_point(opts) do
    case Keyword.get(opts, :start) do
      nil -> opts |> Keyword.fetch!(:bounds) |> Enum.map(fn {lo, hi} -> (lo + hi) / 2 end)
      start -> start
    end
  end

  defp add(a, b), do: Enum.zip_with(a, b, &+/2)
  defp sub(a, b), do: Enum.zip_with(a, b, &-/2)
  defp scale(v, k), do: Enum.map(v, &(&1 * k))
end
