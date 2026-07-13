defmodule NumbersEvolution.Simulations.GoldenMean do
  @moduledoc """
  Convenience facade for "calibrate a simulation to hit the target in ~N attempts".

  Ties the golden-mean solvers to the existing auto-blacklist machinery: it only
  recommends blacklist **sizes** — the engine's `Simulations.generate_auto_blacklist/5`
  still builds the actual, look-ahead-safe blacklist of that size against the
  target draw. So this adds a self-tuning layer without touching the intentional
  VIP2 semantics.

  By default it uses the analytic probe (instant, no simulation). Pass a custom
  `:probe` in `opts` to close the loop on a measured Monte Carlo run instead.
  """

  alias NumbersEvolution.Games
  alias NumbersEvolution.Simulations.Optimizer.Bisection
  alias NumbersEvolution.Simulations.Probe

  @typedoc "A calibration recommendation ready to feed into simulation options."
  @type recommendation :: %{
          main_blacklist_size: non_neg_integer(),
          euro_blacklist_size: non_neg_integer(),
          expected_attempts: number(),
          setpoint: number(),
          iterations: non_neg_integer(),
          game: String.t()
        }

  @doc """
  Recommends blacklist sizes so the expected attempts to jackpot ≈ `setpoint`.

  `opts`:
  - `:game` — game id or config (default: Eurojackpot)
  - `:euro_blacklist` — euro blacklist size to hold fixed (default `0`)
  - `:probe` — custom `(main_bl -> attempts)`; defaults to the analytic probe
  - forwarded to `Bisection.solve/3`: `:max_iter`, `:tol`
  """
  @spec calibrate(number(), keyword()) :: recommendation()
  def calibrate(setpoint, opts \\ []) do
    game = Games.get!(Keyword.get(opts, :game, Games.default_id()))
    euro_bl = Keyword.get(opts, :euro_blacklist, 0)
    probe = Keyword.get(opts, :probe, Probe.make_analytic_probe(game, euro_bl))
    hi = Probe.max_main_blacklist(game)

    {:ok, sol} = Bisection.solve(setpoint, %{probe: probe, lo: 0, hi: hi}, opts)

    %{
      main_blacklist_size: sol.params.main_blacklist_size,
      euro_blacklist_size: euro_bl,
      expected_attempts: sol.metric,
      setpoint: setpoint,
      iterations: sol.iterations,
      game: game.id
    }
  end

  @doc """
  Turns a calibration into the string-keyed options map consumed by
  `Simulations.create_and_start_simulation/2` (auto-blacklist of the tuned size).
  """
  @spec to_options(recommendation()) :: %{String.t() => term()}
  def to_options(%{main_blacklist_size: main, euro_blacklist_size: euro}) do
    %{
      "auto_blacklist" => true,
      "auto_blacklist_main_size" => main,
      "auto_blacklist_euro_size" => euro
    }
  end
end
