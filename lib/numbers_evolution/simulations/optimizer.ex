defmodule NumbersEvolution.Simulations.Optimizer do
  @moduledoc """
  Behaviour shared by every self-optimizer in the simulation stack.

  An optimizer searches a parameter space to drive a measured metric toward a
  `setpoint` (the "golden mean", e.g. *hit the target in ~100 attempts*) or to
  extremize an objective. The `context` map carries whatever an implementation
  needs — an analytic game config, an injected probe function, a population,
  a bandit portfolio — so the same contract fits the analytic inverter, the
  bisection controller, the genetic search and the bandit mixer alike.

  Implementations must be **pure given their inputs** (any randomness comes from
  a seeded process RNG), so optimization runs are reproducible.
  """

  @typedoc "What an optimizer returns: chosen params, the metric it achieved, and effort spent."
  @type solution :: %{
          params: map(),
          metric: number(),
          iterations: non_neg_integer(),
          converged: boolean()
        }

  @doc """
  Drive the metric toward `setpoint` within `context`/`opts`.

  Returns `{:ok, solution}` or `{:error, reason}` when the space is infeasible.
  """
  @callback solve(setpoint :: number(), context :: map(), opts :: keyword()) ::
              {:ok, solution()} | {:error, term()}
end
