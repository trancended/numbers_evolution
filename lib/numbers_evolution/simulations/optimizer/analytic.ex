defmodule NumbersEvolution.Simulations.Optimizer.Analytic do
  @moduledoc """
  ALG-1 — Golden-Mean Analytic inverter.

  Chooses blacklist sizes `(main_bl, euro_bl)` so the theoretical search space
  (≈ expected attempts to jackpot) lands as close as possible to a `setpoint`
  (e.g. 100). Pure closed-form search over the small feasible grid — no
  simulation needed — so it is the instant answer to "simulate hitting the
  target in ~N attempts" and the seed for the feedback controller (ALG-2).

  Ties (equal distance to the setpoint) are broken toward the **smaller** total
  blacklist, i.e. the least amount of look-ahead needed to reach the setpoint.

  `context` keys:
  - `:game` — game id or config (default: Eurojackpot)
  """

  @behaviour NumbersEvolution.Simulations.Optimizer

  alias NumbersEvolution.Games
  alias NumbersEvolution.Simulations.Probe

  @impl true
  def solve(setpoint, context \\ %{}, _opts \\ []) do
    game = Games.get!(Map.get(context, :game, Games.default_id()))
    best = search_grid(setpoint, game)

    {:ok,
     %{
       params: %{main_blacklist_size: best.main_bl, euro_blacklist_size: best.euro_bl},
       metric: best.attempts,
       iterations: best.evaluated,
       converged: true
     }}
  end

  defp search_grid(setpoint, game) do
    main_range = 0..Probe.max_main_blacklist(game)
    euro_range = 0..Probe.max_euro_blacklist(game)

    for(main_bl <- main_range, euro_bl <- euro_range, do: {main_bl, euro_bl})
    |> Enum.reduce(nil, fn {main_bl, euro_bl}, acc ->
      attempts = Probe.search_space(main_bl, euro_bl, game)
      keep_better(acc, %{main_bl: main_bl, euro_bl: euro_bl, attempts: attempts}, setpoint)
    end)
    |> Map.put(:evaluated, Enum.count(main_range) * Enum.count(euro_range))
  end

  # Prefer smaller |attempts - setpoint|; on a tie prefer the smaller total
  # blacklist (less look-ahead bias for the same calibration).
  defp keep_better(nil, cand, _setpoint), do: cand

  defp keep_better(current, cand, setpoint) do
    if better?(cand, current, setpoint), do: cand, else: current
  end

  defp better?(cand, current, setpoint) do
    d_cand = abs(cand.attempts - setpoint)
    d_cur = abs(current.attempts - setpoint)

    cond do
      d_cand < d_cur -> true
      d_cand > d_cur -> false
      true -> cand.main_bl + cand.euro_bl < current.main_bl + current.euro_bl
    end
  end
end
