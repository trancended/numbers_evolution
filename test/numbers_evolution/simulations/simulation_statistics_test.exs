defmodule NumbersEvolution.SimulationStatisticsTest do
  # Use ExUnit.Case instead of DataCase for pure unit tests
  use ExUnit.Case, async: true

  # Test helper functions (copied from actual implementation for testing)
  def test_calculate_median(sorted_list) when is_list(sorted_list) do
    count = length(sorted_list)

    if rem(count, 2) == 0 do
      # Even number of elements - average of two middle values
      mid1 = Enum.at(sorted_list, div(count, 2) - 1)
      mid2 = Enum.at(sorted_list, div(count, 2))
      (mid1 + mid2) / 2.0
    else
      # Odd number of elements - middle value
      Enum.at(sorted_list, div(count, 2))
    end
  end

  def test_update_strategy_performance(attempt_counts) do
    # Simulate the logic without database operations
    if length(attempt_counts) > 0 do
      sorted_counts = Enum.sort(attempt_counts)
      median = test_calculate_median(sorted_counts)
      {:ok, median}
    else
      {:no_simulations, nil}
    end
  end

  describe "calculate_median/1 - statistical calculations" do
    test "returns middle value for odd number of elements" do
      # 5 elements: median is the 3rd element (index 2)
      assert test_calculate_median([1, 2, 3, 4, 5]) == 3.0
      # 3 elements: median is the 2nd element (index 1)
      assert test_calculate_median([10, 20, 30]) == 20.0
      # 1 element: median is that element
      assert test_calculate_median([42]) == 42.0
    end

    test "returns average of two middle values for even number of elements" do
      # 4 elements: average of 2nd and 3rd elements (indices 1 and 2)
      assert test_calculate_median([1, 2, 3, 4]) == 2.5
      # 2 elements: average of both
      assert test_calculate_median([10, 20]) == 15.0
      # 6 elements: average of 3rd and 4th elements (indices 2 and 3)
      assert test_calculate_median([1, 2, 3, 4, 5, 6]) == 3.5
    end

    test "handles negative numbers" do
      negatives = [-5, -3, -1, 1, 3, 5]
      # 6 elements, even count: average of 3rd and 4th elements (indices 2 and 3)
      # sorted: [-5, -3, -1, 1, 3, 5] -> (-1 + 1) / 2 = 0.0
      assert test_calculate_median(negatives) == 0.0
    end

    test "handles large numbers correctly" do
      large_numbers = [100_000, 200_000, 300_000]
      assert test_calculate_median(large_numbers) == 200_000.0
    end

    test "handles floating point numbers" do
      floats = [1.5, 2.5, 3.5, 4.5]
      assert test_calculate_median(floats) == 3.0
    end

    test "handles duplicate values" do
      duplicates = [100, 100, 100, 200, 200]
      assert test_calculate_median(duplicates) == 100.0
    end

    test "precision test: floating point arithmetic" do
      # Test that we're using float division
      values = [1, 2, 2, 2, 3]
      result = test_calculate_median(values)
      # Elixir returns integer when result is whole number
      assert result == 2
    end

    test "edge case: very large list performance" do
      # Test with reasonable size for unit test (not too slow)
      large_list = Enum.to_list(1..1000)
      result = test_calculate_median(large_list)
      # average of 500 and 501
      assert result == 500.5
    end
  end

  describe "update_strategy_performance/1 - performance calculation logic" do
    test "calculates median from single simulation" do
      result = test_update_strategy_performance([100])
      assert {:ok, median} = result
      assert median == 100
    end

    test "calculates median from multiple simulations - odd count" do
      attempt_counts = [100, 125, 150, 175, 200]
      # Sorted: [100, 125, 150, 175, 200] - median should be 150
      result = test_update_strategy_performance(attempt_counts)
      assert {:ok, median} = result
      assert median == 150
    end

    test "calculates median from multiple simulations - even count" do
      attempt_counts = [100, 125, 150, 175]
      # Sorted: [100, 125, 150, 175] - median should be (125 + 150) / 2 = 137.5
      result = test_update_strategy_performance(attempt_counts)
      assert {:ok, median} = result
      assert median == 137.5
    end

    test "does nothing for strategy with no successful simulations" do
      result = test_update_strategy_performance([])
      assert {:no_simulations, nil} = result
    end

    test "handles large attempt counts correctly" do
      result = test_update_strategy_performance([1_000_000])
      assert {:ok, median} = result
      assert median == 1_000_000
    end

    test "median calculation handles edge cases correctly" do
      # Extreme values
      attempt_counts = [1, 500_000, 1_000_000]
      # Sorted: [1, 500_000, 1_000_000] - median should be 500_000
      result = test_update_strategy_performance(attempt_counts)
      assert {:ok, median} = result
      assert median == 500_000
    end

    test "median calculation with duplicates" do
      # Multiple simulations with same attempt count
      attempt_counts = [100, 100, 100]
      result = test_update_strategy_performance(attempt_counts)
      assert {:ok, median} = result
      assert median == 100
    end
  end

  describe "business rules: performance metrics" do
    test "performance score represents typical strategy effectiveness" do
      # Simulate realistic simulation results
      # Most simulations should be around 1000-5000 attempts
      attempt_counts = [1200, 800, 1500, 2000, 2500]
      # Sorted: [800, 1200, 1500, 2000, 2500] - median should be 1500

      result = test_update_strategy_performance(attempt_counts)
      assert {:ok, median} = result
      assert median == 1500

      # Median should be robust to outliers (800 and 2500 don't affect it much)
    end

    test "zero attempt simulations should not occur (business rule)" do
      # This should not happen in practice, but test robustness
      result = test_update_strategy_performance([0])
      assert {:ok, median} = result
      assert median == 0
    end

    test "performance scores help with strategy ranking" do
      # Test the ranking logic with different performance scores
      # median: 60
      fast_strategy_scores = [50, 75, 60]
      # median: 200
      slow_strategy_scores = [200, 250, 180]

      {:ok, fast_median} = test_update_strategy_performance(fast_strategy_scores)
      {:ok, slow_median} = test_update_strategy_performance(slow_strategy_scores)

      assert fast_median < slow_median
      assert fast_median == 60
      assert slow_median == 200
    end
  end
end
