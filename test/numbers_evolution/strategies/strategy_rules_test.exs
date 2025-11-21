defmodule NumbersEvolution.Strategies.StrategyRulesTest do
  use ExUnit.Case, async: true
  use NumbersEvolution.DataCase

  alias NumbersEvolution.Strategies.StrategyRules

  # Helper function to create empty struct for testing
  defp empty_rules do
    %StrategyRules{}
  end

  # Helper to assert changeset errors
  defp assert_changeset_error(changeset, field, message) do
    assert %{^field => [^message]} = errors_on(changeset)
  end

  describe "changeset/2" do
    test "valid complete strategy rules" do
      attrs = %{
        main_numbers: %{
          # 2 parzyste + 3 nieparzyste = 5
          ratio_even_odd: [2, 3],
          # 3 z 1-25 + 2 z 26-50 = 5
          ratio_low_high: [3, 2],
          preferred_hot: [7, 19, 23],
          preferred_cold: [11, 34],
          weights: %{
            hot: 0.5,
            cold: 0.2,
            random: 0.3
          }
        },
        euro_numbers: %{
          # 1 parzysta + 1 nieparzysta = 2
          ratio_even_odd: [1, 1],
          preferred: [3, 7],
          weights: %{
            hot: 0.6,
            random: 0.4
          }
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :main_numbers)
      assert get_change(changeset, :euro_numbers)
    end

    test "missing main_numbers field" do
      attrs = %{
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          preferred: [3, 7],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      assert_changeset_error(changeset, :main_numbers, "can't be blank")
    end

    test "missing euro_numbers field" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          preferred_hot: [7, 19, 23],
          preferred_cold: [11, 34],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      assert_changeset_error(changeset, :euro_numbers, "can't be blank")
    end

    test "invalid nested structure - main_numbers as string" do
      attrs = %{
        main_numbers: "invalid_string",
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          preferred: [3, 7],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      # Should have errors in the main changeset itself
      assert :main_numbers in Keyword.keys(changeset.errors)
    end

    test "invalid nested structure - euro_numbers as string" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          preferred_hot: [7, 19, 23],
          preferred_cold: [11, 34],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: "invalid_string"
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      # Should have errors in the main changeset itself
      assert :euro_numbers in Keyword.keys(changeset.errors)
    end

    test "empty attributes" do
      attrs = %{}

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      assert_changeset_error(changeset, :main_numbers, "can't be blank")
      assert_changeset_error(changeset, :euro_numbers, "can't be blank")
    end
  end

  describe "validate_ratio_sum/3" do
    test "valid ratio_even_odd for main numbers [2, 3]" do
      attrs = %{
        main_numbers: %{
          # 2 + 3 = 5
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "valid ratio_even_odd for euro numbers [1, 1]" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          # 1 + 1 = 2
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "invalid sum for main numbers ratio_even_odd [3, 3]" do
      attrs = %{
        main_numbers: %{
          # 3 + 3 = 6, should be 5
          ratio_even_odd: [3, 3],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      main_changeset = get_change(changeset, :main_numbers)
      refute main_changeset.valid?
      assert :ratio_even_odd in Keyword.keys(main_changeset.errors)
    end

    test "invalid sum for euro numbers ratio_even_odd [2, 1]" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          # 2 + 1 = 3, should be 2
          ratio_even_odd: [2, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      euro_changeset = get_change(changeset, :euro_numbers)
      refute euro_changeset.valid?
      assert :ratio_even_odd in Keyword.keys(euro_changeset.errors)
    end

    test "negative values in ratio [-1, 6]" do
      attrs = %{
        main_numbers: %{
          # negative value
          ratio_even_odd: [-1, 6],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      main_changeset = get_change(changeset, :main_numbers)
      refute main_changeset.valid?
      assert :ratio_even_odd in Keyword.keys(main_changeset.errors)
    end

    test "non-integer values in ratio [2.5, 2.5]" do
      attrs = %{
        main_numbers: %{
          # float values
          ratio_even_odd: [2.5, 2.5],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      main_changeset = get_change(changeset, :main_numbers)
      refute main_changeset.valid?
      assert :ratio_even_odd in Keyword.keys(main_changeset.errors)
    end

    test "invalid format - string instead of list" do
      attrs = %{
        main_numbers: %{
          # string instead of list
          ratio_even_odd: "2,3",
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      main_changeset = get_change(changeset, :main_numbers)
      refute main_changeset.valid?
      assert :ratio_even_odd in Keyword.keys(main_changeset.errors)
    end

    test "edge case: all even numbers [5, 0]" do
      attrs = %{
        main_numbers: %{
          # all even
          ratio_even_odd: [5, 0],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "edge case: all odd numbers [0, 5]" do
      attrs = %{
        main_numbers: %{
          # all odd
          ratio_even_odd: [0, 5],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end
  end

  describe "validate_weights_sum/1" do
    test "exact sum 1.0" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # 0.5 + 0.3 + 0.2 = 1.0
          weights: %{hot: 0.5, cold: 0.3, random: 0.2}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          # 0.6 + 0.4 = 1.0
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "sum within tolerance (1.0005)" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # sum ≈ 1.0005
          weights: %{hot: 0.333, cold: 0.333, random: 0.3345}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "sum too high (1.1)" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # 0.5 + 0.4 + 0.2 = 1.1
          weights: %{hot: 0.5, cold: 0.4, random: 0.2}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      # The changeset should be invalid due to weights sum validation
      # We don't check specific error keys since validation order may vary
    end

    test "sum too low (0.9)" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # 0.3 + 0.3 + 0.3 = 0.9
          weights: %{hot: 0.3, cold: 0.3, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      # The changeset should be invalid due to weights sum validation
    end

    test "negative weights" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # negative hot
          weights: %{hot: -0.1, cold: 0.6, random: 0.5}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      main_changeset = get_change(changeset, :main_numbers)
      weights_changeset = get_change(main_changeset, :weights)
      refute weights_changeset.valid?
      assert :hot in Keyword.keys(weights_changeset.errors)
    end

    test "weights > 1.0" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # hot > 1.0
          weights: %{hot: 1.5, cold: 0.3, random: 0.2}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      main_changeset = get_change(changeset, :main_numbers)
      weights_changeset = get_change(main_changeset, :weights)
      refute weights_changeset.valid?
      assert :hot in Keyword.keys(weights_changeset.errors)
    end

    test "all weight on one type" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # all on hot
          weights: %{hot: 1.0, cold: 0.0, random: 0.0}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "zero weights (invalid for business logic)" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # all zero
          weights: %{hot: 0.0, cold: 0.0, random: 0.0}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      # The changeset should be invalid due to zero weights sum
    end
  end

  describe "validate_number_range/3" do
    test "main numbers in 1-50 range" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # all in 1-50
          preferred_hot: [7, 19, 23, 42],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "euro numbers in 1-12 range" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          # all in 1-12
          preferred: [3, 7, 11],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "empty preferred lists" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # empty
          preferred_hot: [],
          # empty
          preferred_cold: [],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          # empty
          preferred: [],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "main numbers out of range" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # out of 1-50 range
          preferred_hot: [0, 51, 100],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      main_changeset = get_change(changeset, :main_numbers)
      refute main_changeset.valid?
      assert :preferred_hot in Keyword.keys(main_changeset.errors)
    end

    test "euro numbers out of range" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          # out of 1-12 range
          preferred: [0, 13, 25],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)

      refute changeset.valid?
      euro_changeset = get_change(changeset, :euro_numbers)
      refute euro_changeset.valid?
      assert :preferred in Keyword.keys(euro_changeset.errors)
    end

    test "boundary values - main numbers" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # boundary values
          preferred_hot: [1, 50],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "boundary values - euro numbers" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          # boundary values
          preferred: [1, 12],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end

    test "duplicates allowed" do
      attrs = %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          # duplicates allowed
          preferred_hot: [7, 7, 19, 19],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          weights: %{hot: 0.6, random: 0.4}
        }
      }

      changeset = StrategyRules.changeset(empty_rules(), attrs)
      assert changeset.valid?
    end
  end
end

# Test Data Factories

defmodule TestData do
  @moduledoc """
  Valid test data factories for StrategyRules tests.
  """

  def valid_strategy_rules do
    %{
      main_numbers: valid_main_numbers(),
      euro_numbers: valid_euro_numbers()
    }
  end

  def valid_main_numbers do
    %{
      ratio_even_odd: [2, 3],
      ratio_low_high: [3, 2],
      preferred_hot: [7, 19, 23],
      preferred_cold: [11, 34],
      weights: %{hot: 0.5, cold: 0.2, random: 0.3}
    }
  end

  def valid_euro_numbers do
    %{
      ratio_even_odd: [1, 1],
      preferred: [3, 7],
      weights: %{hot: 0.6, random: 0.4}
    }
  end

  def valid_weights_main do
    %{hot: 0.5, cold: 0.3, random: 0.2}
  end

  def valid_weights_euro do
    %{hot: 0.6, random: 0.4}
  end
end

defmodule InvalidTestData do
  @moduledoc """
  Invalid test data factories for StrategyRules tests.
  """

  def invalid_weights_sum_high do
    # sum = 1.1
    %{hot: 0.5, cold: 0.4, random: 0.2}
  end

  def invalid_weights_sum_low do
    # sum = 0.9
    %{hot: 0.3, cold: 0.3, random: 0.3}
  end

  def invalid_weights_zero do
    # sum = 0.0
    %{hot: 0.0, cold: 0.0, random: 0.0}
  end

  def invalid_weights_negative do
    # negative hot
    %{hot: -0.1, cold: 0.6, random: 0.5}
  end

  def invalid_weights_too_high do
    # hot > 1.0
    %{hot: 1.5, cold: 0.3, random: 0.2}
  end

  def invalid_ratios_main_sum do
    # sums = 6, 6 instead of 5, 5
    %{ratio_even_odd: [3, 3], ratio_low_high: [4, 2]}
  end

  def invalid_ratios_euro_sum do
    # sum = 3 instead of 2
    %{ratio_even_odd: [2, 1]}
  end

  def invalid_ratios_negative do
    # negative values
    %{ratio_even_odd: [-1, 6]}
  end

  def invalid_ratios_float do
    # float values
    %{ratio_even_odd: [2.5, 2.5]}
  end

  def invalid_ratios_string do
    # string instead of list
    %{ratio_even_odd: "2,3"}
  end

  def out_of_range_main_numbers do
    # out of 1-50 range
    %{preferred_hot: [0, 51, 100]}
  end

  def out_of_range_euro_numbers do
    # out of 1-12 range
    %{preferred: [0, 13, 25]}
  end

  def boundary_main_numbers do
    # boundary values
    %{preferred_hot: [1, 50]}
  end

  def boundary_euro_numbers do
    # boundary values
    %{preferred: [1, 12]}
  end

  def duplicate_numbers do
    # duplicates (allowed)
    %{preferred_hot: [7, 7, 19, 19]}
  end
end
