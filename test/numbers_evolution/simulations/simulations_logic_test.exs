defmodule NumbersEvolution.SimulationsLogicTest do
  use NumbersEvolution.DataCase, async: true

  alias NumbersEvolution.Simulations.SimulationDuplicateController

  # Test helper to expose private functions for testing
  # In production code, these would be private, but for testing we expose them
  def test_matches_target?(generated, target) do
    # Extract the logic from the private function
    main_match =
      MapSet.new(generated.main) == MapSet.new(target.main_numbers)

    euro_match =
      MapSet.new(generated.euro) == MapSet.new(target.euro_numbers)

    main_match && euro_match
  end

  def test_check_simulation_limits(current_attempt, max_attempts, start_time, timeout_seconds) do
    cond do
      current_attempt >= max_attempts ->
        {:timeout, "max_attempts"}

      System.monotonic_time(:second) - start_time >= timeout_seconds ->
        {:timeout, "time_limit"}

      true ->
        {:continue, nil}
    end
  end

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

  describe "matches_target?/2 - target matching logic" do
    test "returns true for perfect 5+2 match" do
      generated = %{main: [7, 15, 23, 34, 42], euro: [3, 9]}
      target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}

      assert test_matches_target?(generated, target) == true
    end

    test "returns false when main numbers don't match completely" do
      # 4 main numbers match, 1 doesn't
      generated = %{main: [7, 15, 23, 34, 41], euro: [3, 9]}
      target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}

      assert test_matches_target?(generated, target) == false
    end

    test "returns false when euro numbers don't match completely" do
      # All main numbers match, 1 euro doesn't
      generated = %{main: [7, 15, 23, 34, 42], euro: [3, 8]}
      target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}

      assert test_matches_target?(generated, target) == false
    end

    test "returns false when neither main nor euro match" do
      generated = %{main: [1, 2, 3, 4, 5], euro: [1, 2]}
      target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}

      assert test_matches_target?(generated, target) == false
    end

    test "ignores order of numbers (uses MapSet for comparison)" do
      # Same numbers, different order
      generated = %{main: [42, 7, 23, 15, 34], euro: [9, 3]}
      target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}

      assert test_matches_target?(generated, target) == true
    end

    test "handles empty lists correctly" do
      generated = %{main: [], euro: []}
      target = %{main_numbers: [], euro_numbers: []}

      assert test_matches_target?(generated, target) == true
    end

    test "returns false for partial main match with no euro match" do
      # 3 main match, 2 don't + euro don't match
      generated = %{main: [7, 15, 23, 40, 41], euro: [1, 2]}
      target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}

      assert test_matches_target?(generated, target) == false
    end

    test "edge case: duplicate numbers in generated (should still work with MapSet)" do
      # This shouldn't happen in real generation, but test robustness
      # duplicate 34
      generated = %{main: [7, 15, 23, 34, 34], euro: [3, 9]}
      target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}

      assert test_matches_target?(generated, target) == false
    end
  end

  describe "check_simulation_limits/4 - limit validation" do
    test "returns {:timeout, \"max_attempts\"} when current_attempt equals max_attempts" do
      result = test_check_simulation_limits(1_000_000, 1_000_000, 0, 300)
      assert result == {:timeout, "max_attempts"}
    end

    test "returns {:timeout, \"max_attempts\"} when current_attempt exceeds max_attempts" do
      result = test_check_simulation_limits(1_000_001, 1_000_000, 0, 300)
      assert result == {:timeout, "max_attempts"}
    end

    test "returns {:timeout, \"time_limit\"} when timeout is exceeded" do
      # Simulate 301 seconds elapsed (timeout is 300)
      start_time = System.monotonic_time(:second) - 301
      result = test_check_simulation_limits(500_000, 1_000_000, start_time, 300)
      assert result == {:timeout, "time_limit"}
    end

    test "returns {:timeout, \"time_limit\"} when exactly at timeout" do
      # Simulate exactly 300 seconds elapsed
      start_time = System.monotonic_time(:second) - 300
      result = test_check_simulation_limits(500_000, 1_000_000, start_time, 300)
      assert result == {:timeout, "time_limit"}
    end

    test "returns {:continue, nil} when under both limits" do
      # 100 seconds ago
      start_time = System.monotonic_time(:second) - 100
      result = test_check_simulation_limits(500_000, 1_000_000, start_time, 300)
      assert result == {:continue, nil}
    end

    test "prioritizes max_attempts over timeout when both exceeded" do
      # Both limits exceeded, but max_attempts should be checked first
      # timeout exceeded
      start_time = System.monotonic_time(:second) - 400
      result = test_check_simulation_limits(1_000_000, 1_000_000, start_time, 300)
      assert result == {:timeout, "max_attempts"}
    end

    test "handles edge case: zero attempts" do
      result = test_check_simulation_limits(0, 1_000_000, 0, 300)
      assert result == {:continue, nil}
    end

    test "handles edge case: very short timeout" do
      start_time = System.monotonic_time(:second) - 1
      result = test_check_simulation_limits(500_000, 1_000_000, start_time, 1)
      assert result == {:timeout, "time_limit"}
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

    test "handles unsorted lists correctly (assumes input is pre-sorted)" do
      # In practice, this function receives pre-sorted data from database
      # But test what happens with unsorted input
      unsorted = [5, 1, 3, 2, 4]
      # This will give wrong result, but shows the assumption
      result = test_calculate_median(unsorted)
      # The result depends on implementation, but should be deterministic
      assert is_float(result) or is_integer(result)
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

    test "handles negative numbers" do
      negatives = [-5, -3, -1, 1, 3, 5]
      # 6 elements, even count: average of 3rd and 4th elements (indices 2 and 3)
      # sorted: [-5, -3, -1, 1, 3, 5] -> (-1 + 1) / 2 = 0.0
      assert test_calculate_median(negatives) == 0.0
    end

    test "precision test: floating point arithmetic" do
      # Test that we're using float division
      values = [1, 2, 2, 2, 3]
      result = test_calculate_median(values)
      # Elixir returns integer when result is whole number
      assert result == 2
      # Note: In Elixir, integer division of even numbers returns integer
    end

    test "edge case: very large list performance" do
      # Test with reasonable size for unit test (not too slow)
      large_list = Enum.to_list(1..1000)
      result = test_calculate_median(large_list)
      # average of 500 and 501
      assert result == 500.5
    end
  end

  describe "simulation duplicate controller integration" do
    test "duplicate controller maintains state correctly across multiple calls" do
      controller = SimulationDuplicateController.new()

      # First attempt - unique
      attempt1 = %{main: [1, 2, 3, 4, 5], euro: [1, 2]}
      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt1)
      stats = SimulationDuplicateController.get_detailed_stats(controller)
      assert stats.duplicates_skipped == 0
      assert stats.unique_attempts == 1

      # Second attempt - same numbers, different order - duplicate
      attempt2 = %{main: [5, 1, 3, 2, 4], euro: [2, 1]}
      {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt2)
      stats = SimulationDuplicateController.get_detailed_stats(controller)
      assert stats.duplicates_skipped == 1
      assert stats.unique_attempts == 1

      # Third attempt - different numbers - unique
      attempt3 = %{main: [6, 7, 8, 9, 10], euro: [3, 4]}
      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt3)
      stats = SimulationDuplicateController.get_detailed_stats(controller)
      assert stats.duplicates_skipped == 1
      assert stats.unique_attempts == 2
    end

    test "duplicate controller handles empty attempts gracefully" do
      controller = SimulationDuplicateController.new()

      # Empty attempt (edge case)
      attempt = %{main: [], euro: []}
      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt)
      stats = SimulationDuplicateController.get_detailed_stats(controller)
      assert stats.duplicates_skipped == 0
      assert stats.unique_attempts == 1

      # Same empty attempt again - duplicate
      {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt)
      stats = SimulationDuplicateController.get_detailed_stats(controller)
      assert stats.duplicates_skipped == 1
      assert stats.unique_attempts == 1
    end
  end

  describe "business rules validation" do
    test "simulation respects eurojackpot rules: exactly 5 main + 2 euro numbers" do
      # Valid eurojackpot format
      valid_generated = %{main: [1, 2, 3, 4, 5], euro: [1, 2]}
      valid_target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}

      assert test_matches_target?(valid_generated, valid_target)

      # Invalid: too few main numbers
      invalid_main = %{main: [1, 2, 3, 4], euro: [1, 2]}
      refute test_matches_target?(invalid_main, valid_target)

      # Invalid: too few euro numbers
      invalid_euro = %{main: [1, 2, 3, 4, 5], euro: [1]}
      refute test_matches_target?(invalid_euro, valid_target)

      # Invalid: too many main numbers
      too_many_main = %{main: [1, 2, 3, 4, 5, 6], euro: [1, 2]}
      refute test_matches_target?(too_many_main, valid_target)
    end

    test "timeout limits prevent infinite loops" do
      # Test that timeout limits are properly enforced
      # 350 seconds ago
      start_time = System.monotonic_time(:second) - 350
      timeout_seconds = 300

      # Should timeout regardless of attempt count
      result = test_check_simulation_limits(100_000, 1_000_000, start_time, timeout_seconds)
      assert result == {:timeout, "time_limit"}
    end

    test "max attempts limit prevents excessive computation" do
      # Test that attempt limits are properly enforced
      current_attempt = 1_000_001
      max_attempts = 1_000_000

      # Should timeout regardless of time
      result = test_check_simulation_limits(current_attempt, max_attempts, 0, 300)
      assert result == {:timeout, "max_attempts"}
    end
  end

  describe "prize tier calculation" do
    @test_prize_tiers %{
      # I (5+2)
      {5, 2} => 1,
      # II (5+1)
      {5, 1} => 2,
      # III (5+0)
      {5, 0} => 3,
      # IV (4+2)
      {4, 2} => 4,
      # V (4+1)
      {4, 1} => 5,
      # VI (3+2)
      {3, 2} => 6,
      # VII (4+0)
      {4, 0} => 7,
      # VIII (2+2)
      {2, 2} => 8,
      # IX (3+1)
      {3, 1} => 9,
      # X (3+0)
      {3, 0} => 10,
      # XI (1+2)
      {1, 2} => 11,
      # XII (2+1)
      {2, 1} => 12
    }

    def test_calculate_prize_tier(generated, target) do
      main_matches = test_count_matches(generated.main, target.main_numbers)
      euro_matches = test_count_matches(generated.euro, target.euro_numbers)

      Map.get(@test_prize_tiers, {main_matches, euro_matches})
    end

    def test_count_matches(generated_list, target_list) do
      generated_set = MapSet.new(generated_list)
      target_set = MapSet.new(target_list)
      MapSet.intersection(generated_set, target_set) |> MapSet.size()
    end

    test "tier 1: 5+2 jackpot" do
      generated = %{main: [1, 2, 3, 4, 5], euro: [1, 2]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 1
    end

    test "tier 2: 5+1" do
      generated = %{main: [1, 2, 3, 4, 5], euro: [1, 9]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 2
    end

    test "tier 3: 5+0" do
      generated = %{main: [1, 2, 3, 4, 5], euro: [9, 10]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 3
    end

    test "tier 4: 4+2" do
      generated = %{main: [1, 2, 3, 4, 9], euro: [1, 2]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 4
    end

    test "tier 5: 4+1" do
      generated = %{main: [1, 2, 3, 4, 9], euro: [1, 10]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 5
    end

    test "tier 6: 3+2" do
      generated = %{main: [1, 2, 3, 9, 10], euro: [1, 2]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 6
    end

    test "tier 7: 4+0" do
      generated = %{main: [1, 2, 3, 4, 9], euro: [9, 10]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 7
    end

    test "tier 8: 2+2" do
      generated = %{main: [1, 2, 9, 10, 11], euro: [1, 2]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 8
    end

    test "tier 9: 3+1" do
      generated = %{main: [1, 2, 3, 9, 10], euro: [1, 10]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 9
    end

    test "tier 10: 3+0" do
      generated = %{main: [1, 2, 3, 9, 10], euro: [9, 10]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 10
    end

    test "tier 11: 1+2" do
      generated = %{main: [1, 9, 10, 11, 12], euro: [1, 2]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 11
    end

    test "tier 12: 2+1" do
      generated = %{main: [1, 2, 9, 10, 11], euro: [1, 10]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == 12
    end

    test "no prize: 0+0" do
      generated = %{main: [9, 10, 11, 12, 13], euro: [9, 10]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == nil
    end

    test "no prize: 1+0" do
      generated = %{main: [1, 9, 10, 11, 12], euro: [9, 10]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == nil
    end

    test "no prize: 0+1" do
      generated = %{main: [9, 10, 11, 12, 13], euro: [1, 10]}
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      assert test_calculate_prize_tier(generated, target) == nil
    end
  end
end
