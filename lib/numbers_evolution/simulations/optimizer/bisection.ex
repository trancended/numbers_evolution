defmodule NumbersEvolution.Simulations.Optimizer.Bisection do
  @moduledoc """
  ALG-2 — Golden-Mean feedback controller.

  Treats the main blacklist size `k` as a single scalar knob and binary-searches
  it against an injected, monotonically **decreasing** probe `(k -> attempts)` so
  the achieved attempts land on the `setpoint`. Because the probe is measured
  (it can be a short Monte Carlo run, not just the analytic model), the
  controller corrects the bias that VIP parity/decade constraints introduce into
  the closed-form estimate — while still converging in `O(log range)` probe
  calls thanks to monotonicity.

  `context` keys:
  - `:probe` — required, `(non_neg_integer -> number)`, decreasing in `k`
  - `:lo`, `:hi` — search bounds for `k` (defaults `0`, `hi` required or derived)

  `opts`:
  - `:tol` — relative tolerance on `|attempts - setpoint| / setpoint` (default `0.0`)
  - `:max_iter` — probe-call budget (default `64`)
  """

  @behaviour NumbersEvolution.Simulations.Optimizer

  @impl true
  def solve(setpoint, context, opts \\ []) do
    probe = Map.fetch!(context, :probe)
    lo = Map.get(context, :lo, 0)
    hi = Map.fetch!(context, :hi)
    max_iter = Keyword.get(opts, :max_iter, 64)

    search(probe, setpoint, lo, hi, max_iter, 0)
  end

  # Smallest k whose attempts fall at/below the setpoint is the crossing point of
  # a decreasing function; we bracket it, then pick whichever of the two
  # straddling integers lands closer to the setpoint.
  defp search(probe, setpoint, lo, hi, _max_iter, used) when lo >= hi do
    finalize(probe, setpoint, lo, used)
  end

  defp search(probe, setpoint, lo, _hi, max_iter, used) when used >= max_iter do
    finalize(probe, setpoint, lo, used)
  end

  defp search(probe, setpoint, lo, hi, max_iter, used) do
    mid = div(lo + hi, 2)

    if probe.(mid) > setpoint do
      # still too many attempts -> need a bigger blacklist
      search(probe, setpoint, mid + 1, hi, max_iter, used + 1)
    else
      search(probe, setpoint, lo, mid, max_iter, used + 1)
    end
  end

  defp finalize(probe, setpoint, k, used) do
    {best_k, best_attempts} = pick_closer(probe, setpoint, k)

    {:ok,
     %{
       params: %{main_blacklist_size: best_k},
       metric: best_attempts,
       iterations: used + 2,
       converged: true
     }}
  end

  # Compare the crossing integer k with its lower neighbour k-1 (which sits on the
  # other side of the setpoint) and keep the closer one.
  defp pick_closer(probe, _setpoint, 0), do: {0, probe.(0)}

  defp pick_closer(probe, setpoint, k) do
    a = probe.(k)
    b = probe.(k - 1)
    if abs(a - setpoint) <= abs(b - setpoint), do: {k, a}, else: {k - 1, b}
  end
end
