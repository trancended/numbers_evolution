defmodule NumbersEvolution.Simulations.Objective do
  @moduledoc """
  The multi-criteria objective that the meta-optimizers minimize.

  Combines the "golden-mean" calibration term with value, robustness, coverage
  and a bias guard rail so a single scalar can express what a *good* simulation
  configuration means — while the guard rail stops an optimizer from degenerating
  to the trivial "blacklist everything except the target" solution.

      f(θ) = w_setpoint · |E[attempts] − setpoint| / setpoint
           + w_ev        · (−roi)
           + w_robust    · (−robustness)
           + w_coverage  · (−coverage)
           + w_bias      · bias_penalty(search_space)

  Presets pick the weight balance:
  - `:calibration` — hit ~N attempts (setpoint dominates)
  - `:value`       — maximize EV / robustness
  - `:balanced`    — a bit of everything
  """

  @presets %{
    calibration: %{setpoint: 1.0, ev: 0.1, robustness: 0.1, coverage: 0.0, bias: 1.0},
    value: %{setpoint: 0.1, ev: 1.0, robustness: 0.5, coverage: 0.2, bias: 1.0},
    balanced: %{setpoint: 0.5, ev: 0.5, robustness: 0.3, coverage: 0.2, bias: 1.0}
  }

  @default_min_space 20

  @doc "Weight map for a named preset."
  @spec preset(atom()) :: map()
  def preset(name), do: Map.fetch!(@presets, name)

  @doc """
  Scalar score (lower is better) for a `metrics` map. Recognized keys (all
  optional, neutral when absent):

  - `:expected_attempts`, `:setpoint` — calibration term
  - `:roi` — value term (dimensionless EV / cost)
  - `:robustness` — stability across draws (higher = better)
  - `:coverage` — fraction of space explored (0..1)
  - `:search_space` — feeds the bias guard rail

  `opts`: `:weights` (map or preset atom, default `:balanced`), `:min_space`.
  """
  @spec score(map(), keyword()) :: float()
  def score(metrics, opts \\ []) do
    w = weights(Keyword.get(opts, :weights, :balanced))
    min_space = Keyword.get(opts, :min_space, @default_min_space)

    w.setpoint * setpoint_term(metrics) +
      w.ev * -Map.get(metrics, :roi, 0.0) +
      w.robustness * -Map.get(metrics, :robustness, 0.0) +
      w.coverage * -Map.get(metrics, :coverage, 0.0) +
      w.bias * bias_penalty(Map.get(metrics, :search_space), min_space)
  end

  @doc """
  Guard rail: a soft barrier that grows as the search space shrinks below
  `min_space`, plus a hard spike at a degenerate space (≤ 1 combination).
  """
  @spec bias_penalty(number() | nil, pos_integer()) :: float()
  def bias_penalty(nil, _min_space), do: 0.0
  def bias_penalty(space, _min_space) when space <= 1, do: 1.0e6

  def bias_penalty(space, min_space) when space < min_space do
    deficit = (min_space - space) / min_space
    deficit * deficit * 100.0
  end

  def bias_penalty(_space, _min_space), do: 0.0

  defp setpoint_term(%{expected_attempts: attempts, setpoint: setpoint})
       when is_number(attempts) and is_number(setpoint) and setpoint > 0 do
    abs(attempts - setpoint) / setpoint
  end

  defp setpoint_term(_metrics), do: 0.0

  defp weights(name) when is_atom(name), do: preset(name)
  defp weights(map) when is_map(map), do: Map.merge(preset(:balanced), map)
end
