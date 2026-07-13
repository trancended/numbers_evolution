defmodule NumbersEvolution.Simulations.Genome do
  @moduledoc """
  Encoder/decoder between a strategy's tunable parameters and the flat float
  vector the meta-optimizers (`Optimizer.Genetic`, `NelderMead`, `Bayesian`)
  operate on. This is the bridge that lets those optimizers *evolve strategies*.

  Genome layout (6 dimensions):

      [main_hot, main_cold, main_random, euro_hot, euro_random, main_blacklist_size]

  The five weight genes are unconstrained logits turned into valid, sum-to-one
  weight maps via softmax (so any optimizer output decodes to a legal strategy),
  and the last gene is the blacklist size (rounded, clamped to the feasible
  range). `to_rules_attrs/2` produces a map accepted by
  `Strategies.StrategyRules.changeset/2`.
  """

  alias NumbersEvolution.Simulations.Probe

  @logit_bound 4.0

  @type decoded :: %{
          main_weights: %{hot: float(), cold: float(), random: float()},
          euro_weights: %{hot: float(), random: float()},
          main_blacklist_size: non_neg_integer()
        }

  @doc "Optimizer bounds for the 6-gene genome, given a game."
  @spec bounds(String.t() | map()) :: [{float(), float()}]
  def bounds(game \\ NumbersEvolution.Games.default_id()) do
    weight_bounds = List.duplicate({-@logit_bound, @logit_bound}, 5)
    weight_bounds ++ [{0.0, Probe.max_main_blacklist(game) * 1.0}]
  end

  @doc "Decode a genome vector into strategy parameters."
  @spec decode([float()], String.t() | map()) :: decoded()
  def decode([mh, mc, mr, eh, er, bl], game \\ NumbersEvolution.Games.default_id()) do
    [w_hot, w_cold, w_random] = softmax([mh, mc, mr])
    [e_hot, e_random] = softmax([eh, er])
    max_bl = Probe.max_main_blacklist(game)

    %{
      main_weights: %{hot: w_hot, cold: w_cold, random: w_random},
      euro_weights: %{hot: e_hot, random: e_random},
      main_blacklist_size: bl |> round() |> max(0) |> min(max_bl)
    }
  end

  @doc """
  Build a `StrategyRules`-compatible attrs map from a decoded genome.

  Ratios default to a balanced split (overridable via `opts`), since the genome
  optimizes the continuous weights and blacklist size; `preferred_hot`/`_cold`
  can be supplied via `opts` to keep hot/cold pools meaningful.
  """
  @spec to_rules_attrs(decoded(), keyword()) :: map()
  def to_rules_attrs(decoded, opts \\ []) do
    %{
      "main_numbers" => %{
        "ratio_even_odd" => Keyword.get(opts, :main_even_odd, [2, 3]),
        "ratio_low_high" => Keyword.get(opts, :main_low_high, [2, 3]),
        "preferred_hot" => Keyword.get(opts, :main_hot, []),
        "preferred_cold" => Keyword.get(opts, :main_cold, []),
        "weights" => round_weights(decoded.main_weights, [:hot, :cold, :random])
      },
      "euro_numbers" => %{
        "ratio_even_odd" => Keyword.get(opts, :euro_even_odd, [1, 1]),
        "preferred" => Keyword.get(opts, :euro_hot, []),
        "weights" => round_weights(decoded.euro_weights, [:hot, :random])
      }
    }
  end

  @doc "Numerically stable softmax of a logit list (returns a probability list)."
  @spec softmax([float()]) :: [float()]
  def softmax(logits) do
    m = Enum.max(logits)
    exps = Enum.map(logits, fn l -> :math.exp(l - m) end)
    total = Enum.sum(exps)
    Enum.map(exps, &(&1 / total))
  end

  # Round weights to 3 dp and fix rounding drift on the last key so the sum stays 1.0.
  defp round_weights(weights, keys) do
    rounded = Map.new(keys, fn k -> {k, Float.round(weights[k], 3)} end)
    drift = 1.0 - (rounded |> Map.values() |> Enum.sum())
    last = List.last(keys)
    rounded |> Map.update!(last, &Float.round(&1 + drift, 3)) |> stringify()
  end

  defp stringify(map), do: Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end)
end
