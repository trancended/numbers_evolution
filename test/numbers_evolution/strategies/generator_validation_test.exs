defmodule NumbersEvolution.Strategies.GeneratorValidationTest do
  @moduledoc """
  Tests for strategy constraint validation against target draws.
  """
  use NumbersEvolution.DataCase

  alias NumbersEvolution.Strategies.{Generator, Strategy}

  describe "validate_strategy_constraints/3" do
    test "validates VIP strategy with correct constraints" do
      strategy = %Strategy{
        name: "VIP1 Test",
        rules: %{
          main_numbers: %{
            ratio_even_odd: [3, 2],
            ratio_low_high: [3, 2],
            preferred_hot: [],
            preferred_cold: [],
            blacklist: [],
            weights: %{hot: 0.4, cold: 0.2, random: 0.4}
          },
          euro_numbers: %{
            ratio_even_odd: [1, 1],
            preferred: [],
            blacklist: [],
            weights: %{hot: 0.5, random: 0.5}
          }
        }
      }

      # Valid VIP draw: 2 odd + 3 even, max 2 per decade
      # Odd: 7, 15; Even: 2, 4, 24
      # Decades: 1-10 (2,4,7), 11-20 (15), 21-30 (24) - max 3 in first decade, should fail
      target_main = [2, 4, 15, 24, 35]
      target_euro = [1, 2]

      assert :ok = Generator.validate_strategy_constraints(strategy, target_main, target_euro)
    end

    test "rejects VIP strategy with wrong parity" do
      strategy = %Strategy{
        name: "VIP2 Strategy",
        rules: %{
          main_numbers: %{
            ratio_even_odd: [3, 2],
            ratio_low_high: [3, 2],
            preferred_hot: [],
            preferred_cold: [],
            blacklist: [],
            weights: %{hot: 0.4, cold: 0.2, random: 0.4}
          },
          euro_numbers: %{
            ratio_even_odd: [1, 1],
            preferred: [],
            blacklist: [],
            weights: %{hot: 0.5, random: 0.5}
          }
        }
      }

      # Invalid: 4 odd + 1 even (should be 2 odd + 3 even)
      target_main = [1, 3, 5, 7, 10]
      target_euro = [1, 2]

      assert {:error, errors} =
               Generator.validate_strategy_constraints(strategy, target_main, target_euro)

      assert Enum.any?(errors, &String.contains?(&1, "2 nieparzyste i 3 parzyste"))
    end

    test "rejects VIP strategy with too many numbers in one decade" do
      strategy = %Strategy{
        name: "VIP1 Advanced",
        rules: %{
          main_numbers: %{
            ratio_even_odd: [3, 2],
            ratio_low_high: [3, 2],
            preferred_hot: [],
            preferred_cold: [],
            blacklist: [],
            weights: %{hot: 0.4, cold: 0.2, random: 0.4}
          },
          euro_numbers: %{
            ratio_even_odd: [1, 1],
            preferred: [],
            blacklist: [],
            weights: %{hot: 0.5, random: 0.5}
          }
        }
      }

      # Invalid: 3 numbers in decade 21-30 (23, 24, 26)
      target_main = [8, 23, 24, 26, 35]
      target_euro = [1, 2]

      assert {:error, errors} =
               Generator.validate_strategy_constraints(strategy, target_main, target_euro)

      assert Enum.any?(errors, &String.contains?(&1, "Maksymalnie 2 liczby w jednej dziesiątce"))
    end

    test "validates strategy with only even numbers requirement" do
      strategy = %Strategy{
        name: "Only Even Strategy",
        rules: %{
          main_numbers: %{
            ratio_even_odd: [5, 0],
            ratio_low_high: [3, 2],
            preferred_hot: [],
            preferred_cold: [],
            blacklist: [],
            weights: %{hot: 0.5, cold: 0.0, random: 0.5}
          },
          euro_numbers: %{
            ratio_even_odd: [2, 0],
            preferred: [],
            blacklist: [],
            weights: %{hot: 0.5, random: 0.5}
          }
        }
      }

      # Valid: all even numbers
      target_main = [2, 4, 6, 8, 10]
      target_euro = [2, 4]

      assert :ok = Generator.validate_strategy_constraints(strategy, target_main, target_euro)
    end

    test "rejects strategy with only even numbers when draw has odd" do
      strategy = %Strategy{
        name: "Only Even Strategy",
        rules: %{
          main_numbers: %{
            ratio_even_odd: [5, 0],
            ratio_low_high: [3, 2],
            preferred_hot: [],
            preferred_cold: [],
            blacklist: [],
            weights: %{hot: 0.5, cold: 0.0, random: 0.5}
          },
          euro_numbers: %{
            ratio_even_odd: [2, 0],
            preferred: [],
            blacklist: [],
            weights: %{hot: 0.5, random: 0.5}
          }
        }
      }

      # Invalid: has odd numbers (3, 5)
      target_main = [2, 3, 5, 6, 8]
      target_euro = [2, 4]

      assert {:error, errors} =
               Generator.validate_strategy_constraints(strategy, target_main, target_euro)

      assert Enum.any?(errors, &String.contains?(&1, "tylko parzystych"))
    end

    test "validates strategy with blacklist" do
      strategy = %Strategy{
        name: "Blacklist Strategy",
        rules: %{
          main_numbers: %{
            ratio_even_odd: [3, 2],
            ratio_low_high: [3, 2],
            preferred_hot: [],
            preferred_cold: [],
            blacklist: [13, 7, 21],
            weights: %{hot: 0.5, cold: 0.0, random: 0.5}
          },
          euro_numbers: %{
            ratio_even_odd: [1, 1],
            preferred: [],
            blacklist: [11],
            weights: %{hot: 0.5, random: 0.5}
          }
        }
      }

      # Valid: no blacklisted numbers (7, 13, 21 are blacklisted for main, 11 for euro)
      target_main = [2, 4, 9, 15, 23]
      target_euro = [1, 2]

      assert :ok = Generator.validate_strategy_constraints(strategy, target_main, target_euro)
    end

    test "rejects strategy when draw contains blacklisted numbers" do
      strategy = %Strategy{
        name: "Blacklist Strategy",
        rules: %{
          main_numbers: %{
            ratio_even_odd: [3, 2],
            ratio_low_high: [3, 2],
            preferred_hot: [],
            preferred_cold: [],
            blacklist: [13, 7, 21],
            weights: %{hot: 0.5, cold: 0.0, random: 0.5}
          },
          euro_numbers: %{
            ratio_even_odd: [1, 1],
            preferred: [],
            blacklist: [11],
            weights: %{hot: 0.5, random: 0.5}
          }
        }
      }

      # Invalid: contains blacklisted main number 13 and euro number 11
      target_main = [2, 4, 9, 13, 23]
      target_euro = [1, 11]

      assert {:error, errors} =
               Generator.validate_strategy_constraints(strategy, target_main, target_euro)

      assert Enum.any?(errors, &String.contains?(&1, "blackliście"))
      assert Enum.any?(errors, &String.contains?(&1, "13"))
      assert Enum.any?(errors, &String.contains?(&1, "11"))
    end

    test "validates normal strategy without strict constraints" do
      strategy = %Strategy{
        name: "Balanced Strategy",
        rules: %{
          main_numbers: %{
            ratio_even_odd: [3, 2],
            ratio_low_high: [3, 2],
            preferred_hot: [1, 2, 3],
            preferred_cold: [45, 46, 47],
            blacklist: [],
            weights: %{hot: 0.4, cold: 0.2, random: 0.4}
          },
          euro_numbers: %{
            ratio_even_odd: [1, 1],
            preferred: [1, 2, 3],
            blacklist: [],
            weights: %{hot: 0.5, random: 0.5}
          }
        }
      }

      # Normal strategy allows various ratios as long as they're not 0
      target_main = [1, 3, 5, 7, 9]
      target_euro = [1, 2]

      assert :ok = Generator.validate_strategy_constraints(strategy, target_main, target_euro)
    end
  end
end
