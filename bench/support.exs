defmodule Bench.Support do
  @moduledoc """
  Shared fixtures for benchmark scripts. Run benches with:

      mix run --no-start bench/components_bench.exs
      mix run --no-start bench/e2e_bench.exs
  """

  alias NumbersEvolution.Strategies.Strategy

  # Target draw satisfying VIP constraints (2 odd + 3 even, max 2 per decade)
  def target_numbers do
    %{main_numbers: [2, 11, 24, 33, 46], euro_numbers: [5, 8]}
  end

  # Fixed VIP2 blacklist (25 main / 6 euro) that does not block the target
  def vip2_blacklist do
    %{
      main_blacklist: [1, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 25, 26, 27, 28],
      euro_blacklist: [1, 2, 3, 4, 6, 7]
    }
  end

  def standard_strategy do
    build_strategy("Bench Standard", %{
      "main_numbers" => %{
        "ratio_even_odd" => [3, 2],
        "ratio_low_high" => [2, 3],
        "preferred_hot" => [7, 12, 23, 34, 45],
        "preferred_cold" => [2, 19, 38],
        "blacklist" => [],
        "weights" => %{"hot" => 0.3, "cold" => 0.2, "random" => 0.5}
      },
      "euro_numbers" => %{
        "ratio_even_odd" => [1, 1],
        "preferred" => [3, 8],
        "blacklist" => [],
        "weights" => %{"hot" => 0.3, "random" => 0.7}
      }
    })
  end

  def random_attempt do
    %{main: Enum.take_random(1..50, 5), euro: Enum.take_random(1..12, 2)}
  end

  defp build_strategy(name, rules) do
    %Strategy{}
    |> Strategy.changeset(%{"name" => name, "type" => "manual", "rules" => rules})
    |> Ecto.Changeset.apply_changes()
  end
end
