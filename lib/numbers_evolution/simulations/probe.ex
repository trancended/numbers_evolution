defmodule NumbersEvolution.Simulations.Probe do
  @moduledoc """
  Cheap estimators of "expected attempts to hit the target" as a function of the
  search-space knobs (blacklist sizes). Optimizers call a probe to score a
  candidate `θ` without running a full simulation.

  Two flavours:

  - **Analytic** (`analytic_attempts/3`): under an i.i.d. uniform model with the
    intentional look-ahead (target always reachable), the per-attempt hit
    probability is `1 / search_space`, so `E[attempts] ≈ search_space`. Exact for
    the model, biased by VIP parity/decade constraints — hence the feedback
    controller (`Optimizer.Bisection`) can wrap a *measured* Monte Carlo probe to
    correct that bias while keeping the same monotonic contract.

  The analytic probe is monotonically **decreasing** in blacklist size (more
  blacklisted numbers ⇒ smaller space ⇒ fewer attempts), which is exactly the
  property the bisection solver relies on.
  """

  alias NumbersEvolution.{Analytics, Games}

  @doc """
  Theoretical search space `C(main_pop - main_bl, main_count) * C(euro_pop - euro_bl, euro_count)`.
  """
  @spec search_space(non_neg_integer(), non_neg_integer(), String.t() | map()) ::
          non_neg_integer()
  def search_space(main_bl, euro_bl, game \\ Games.default_id()) do
    game = Games.get!(game)
    main_avail = main_pop(game) - main_bl
    euro_avail = euro_pop(game) - euro_bl
    Analytics.comb(main_avail, game.main.count) * Analytics.comb(euro_avail, game.bonus.count)
  end

  @doc "Analytic expected attempts to jackpot for the given blacklist sizes (= search space)."
  @spec analytic_attempts(non_neg_integer(), non_neg_integer(), String.t() | map()) ::
          non_neg_integer()
  def analytic_attempts(main_bl, euro_bl, game \\ Games.default_id()) do
    search_space(main_bl, euro_bl, game)
  end

  @doc """
  Builds a monotonic-decreasing probe `(main_bl :: integer -> attempts)` with the
  euro blacklist held fixed — the exact shape `Optimizer.Bisection` consumes.
  """
  @spec make_analytic_probe(String.t() | map(), non_neg_integer()) ::
          (non_neg_integer() -> non_neg_integer())
  def make_analytic_probe(game \\ Games.default_id(), euro_bl \\ 0) do
    game = Games.get!(game)
    fn main_bl -> search_space(main_bl, euro_bl, game) end
  end

  @doc "Largest feasible main blacklist: leaves at least `main.count` pickable numbers."
  @spec max_main_blacklist(String.t() | map()) :: non_neg_integer()
  def max_main_blacklist(game) do
    game = Games.get!(game)
    max(main_pop(game) - game.main.count, 0)
  end

  @doc "Largest feasible euro blacklist: leaves at least `bonus.count` pickable numbers."
  @spec max_euro_blacklist(String.t() | map()) :: non_neg_integer()
  def max_euro_blacklist(game) do
    game = Games.get!(game)
    max(euro_pop(game) - game.bonus.count, 0)
  end

  defp main_pop(game), do: game.main.max - game.main.min + 1
  defp euro_pop(%{bonus: %{count: 0}}), do: 0
  defp euro_pop(game), do: game.bonus.max - game.bonus.min + 1
end
