defmodule NumbersEvolution.Simulations.Search do
  @moduledoc """
  Behaviour for derivative-free optimizers that **minimize** an injected
  objective over a real-valued parameter vector.

  Decoupling the optimizer from the domain (it sees only `vector -> number`)
  keeps the genetic, simplex and Bayesian searches pure and unit-testable on
  classic test functions, and lets them optimize any encodable target — the
  strategy-genome fitness (via `Objective`), a backtest score, or a raw probe.

  Randomized implementations must honour `opts[:seed]` so runs are reproducible.
  """

  @type vector :: [float()]
  @type objective :: (vector() -> number())

  @type solution :: %{
          params: vector(),
          score: float(),
          iterations: non_neg_integer(),
          converged: boolean()
        }

  @doc """
  Minimize `objective`. Common `opts`: `:bounds` (`[{lo, hi}]`), `:max_iter`,
  `:seed`. Implementation-specific options are documented on each module.
  """
  @callback minimize(objective(), opts :: keyword()) :: solution()
end
