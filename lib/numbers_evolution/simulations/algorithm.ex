defmodule NumbersEvolution.Simulations.Algorithm do
  @moduledoc """
  Behaviour for a **candidate-generating engine** — an alternative to the
  standard i.i.d. `Strategies.Generator`. Each engine yields a stream of valid
  combinations via `init/2` + `next/1`, which lets the portfolio bandit
  (`Optimizer.Bandit`) mix engines by pulling `next/1` from whichever arm it
  currently favours.

  Existing generation stays the reference implementation; these engines plug in
  beside it without changing the intentional VIP/look-ahead semantics.
  """

  @type combo :: %{main: [pos_integer()], euro: [pos_integer()]}

  @doc "Build engine state from a game config and options."
  @callback init(game :: map(), opts :: keyword()) :: state :: term()

  @doc "Produce the next candidate combination and the advanced state."
  @callback next(state :: term()) :: {combo(), state :: term()}
end
