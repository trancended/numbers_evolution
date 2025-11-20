defmodule NumbersEvolution.Strategies.GeneratorTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Strategies.Generator
  alias NumbersEvolution.Strategies.Strategy

  describe "generate_numbers/2 with half_random_mode" do
    setup do
      # Create a test strategy with standard rules
      strategy = %Strategy{
        id: "test-strategy",
        name: "Test Strategy",
        type: "manual",
        rules: %{
          main_numbers: %{
            ratio_even_odd: [2, 3],
            ratio_low_high: [3, 2],
            preferred_hot: [],
            preferred_cold: [],
            weights: %{hot: 0.5, cold: 0.0, random: 0.5},
            max_consecutive: 2,
            max_per_decade: 2
          },
          euro_numbers: %{
            ratio_even_odd: [1, 1],
            preferred: [],
            weights: %{hot: 0.5, random: 0.5}
          }
        }
      }

      %{strategy: strategy}
    end

    test "generates numbers in standard mode", %{strategy: strategy} do
      {:ok, result} = Generator.generate_numbers(strategy, half_random_mode: false)

      assert is_map(result)
      assert Map.has_key?(result, :main)
      assert Map.has_key?(result, :euro)
      assert length(result.main) == 5
      assert length(result.euro) == 2
    end

    test "generates numbers in half_random_mode", %{strategy: strategy} do
      {:ok, result} = Generator.generate_numbers(strategy, half_random_mode: true)

      assert is_map(result)
      assert Map.has_key?(result, :main)
      assert Map.has_key?(result, :euro)
      assert length(result.main) == 5
      assert length(result.euro) == 2

      # Check that the result follows half_random logic
      # (we can't easily test the exact pool reduction, but we can test that it generates valid numbers)
      assert Enum.all?(result.main, &(&1 in 1..50))
      assert Enum.all?(result.euro, &(&1 in 1..12))
      assert length(Enum.uniq(result.main)) == 5
      assert length(Enum.uniq(result.euro)) == 2
    end

    test "strategy with 'Losowo pomin połowę' in name uses half_random logic", %{strategy: strategy} do
      strategy_with_name = %{strategy | name: "Losowo pomin połowę - Test"}

      {:ok, result} = Generator.generate_numbers(strategy_with_name)

      assert is_map(result)
      assert Map.has_key?(result, :main)
      assert Map.has_key?(result, :euro)
      assert length(result.main) == 5
      assert length(result.euro) == 2
    end
  end
end
