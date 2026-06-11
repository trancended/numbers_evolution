defmodule NumbersEvolution.Simulations.SimulationDuplicateControllerTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Simulations.SimulationDuplicateController

  describe "new/0" do
    test "creates a new duplicate controller with empty state" do
      controller = SimulationDuplicateController.new()

      stats = SimulationDuplicateController.get_detailed_stats(controller)
      assert stats.unique_attempts == 0
      assert stats.duplicates_skipped == 0
    end
  end

  describe "check_attempt/2" do
    test "returns :unique for first attempt" do
      controller = SimulationDuplicateController.new()
      attempt = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}

      assert {:unique, updated_controller} =
               SimulationDuplicateController.check_attempt(controller, attempt)

      stats = SimulationDuplicateController.get_detailed_stats(updated_controller)
      assert stats.unique_attempts == 1
      assert stats.duplicates_skipped == 0
    end

    test "returns :duplicate for repeated attempt" do
      controller = SimulationDuplicateController.new()
      attempt = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}

      # First attempt - unique
      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt)

      # Second attempt - duplicate
      assert {:duplicate, updated_controller} =
               SimulationDuplicateController.check_attempt(controller, attempt)

      stats = SimulationDuplicateController.get_detailed_stats(updated_controller)
      assert stats.unique_attempts == 1
      assert stats.duplicates_skipped == 1
    end

    test "treats same numbers in different order as duplicate" do
      controller = SimulationDuplicateController.new()
      attempt1 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      # same numbers, different order
      attempt2 = %{main: [34, 1, 50, 23, 7], euro: [9, 3]}

      # First attempt - unique
      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt1)

      # Second attempt - should be duplicate despite different order
      assert {:duplicate, updated_controller} =
               SimulationDuplicateController.check_attempt(controller, attempt2)

      stats = SimulationDuplicateController.get_detailed_stats(updated_controller)
      assert stats.unique_attempts == 1
      assert stats.duplicates_skipped == 1
    end

    test "treats different numbers as unique" do
      controller = SimulationDuplicateController.new()
      attempt1 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      attempt2 = %{main: [2, 8, 24, 35, 49], euro: [4, 10]}

      # First attempt - unique
      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt1)

      # Second attempt - unique (different numbers)
      assert {:unique, updated_controller} =
               SimulationDuplicateController.check_attempt(controller, attempt2)

      stats = SimulationDuplicateController.get_detailed_stats(updated_controller)
      assert stats.unique_attempts == 2
      assert stats.duplicates_skipped == 0
    end

    test "handles multiple duplicates correctly" do
      controller = SimulationDuplicateController.new()
      attempt1 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      # duplicate
      attempt2 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      # duplicate
      attempt3 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      # unique
      attempt4 = %{main: [2, 8, 24, 35, 49], euro: [4, 10]}

      # First attempt - unique
      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt1)

      # Second attempt - duplicate
      {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt2)

      # Third attempt - duplicate
      {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt3)

      # Fourth attempt - unique
      {:unique, updated_controller} =
        SimulationDuplicateController.check_attempt(controller, attempt4)

      stats = SimulationDuplicateController.get_detailed_stats(updated_controller)
      assert stats.unique_attempts == 2
      assert stats.duplicates_skipped == 2
    end
  end

  describe "generate_combination_hash/2" do
    test "generates consistent keys for same numbers" do
      attempt1 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      # same numbers, different order
      attempt2 = %{main: [34, 1, 50, 23, 7], euro: [9, 3]}

      hash1 =
        SimulationDuplicateController.generate_combination_hash(attempt1.main, attempt1.euro)

      hash2 =
        SimulationDuplicateController.generate_combination_hash(attempt2.main, attempt2.euro)

      assert hash1 == hash2
      assert hash1 == {{1, 7, 23, 34, 50}, {3, 9}}
    end

    test "generates different hashes for different numbers" do
      attempt1 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      attempt2 = %{main: [2, 8, 24, 35, 49], euro: [4, 10]}

      hash1 =
        SimulationDuplicateController.generate_combination_hash(attempt1.main, attempt1.euro)

      hash2 =
        SimulationDuplicateController.generate_combination_hash(attempt2.main, attempt2.euro)

      assert hash1 != hash2
    end
  end

  describe "get_stats/1" do
    test "returns correct stats for controller with no duplicates" do
      controller = SimulationDuplicateController.new()
      attempt1 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      attempt2 = %{main: [2, 8, 24, 35, 49], euro: [4, 10]}

      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt1)
      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt2)

      stats = SimulationDuplicateController.get_stats(controller)
      assert stats == %{duplicates_skipped: 0}
    end

    test "returns correct stats for controller with duplicates" do
      controller = SimulationDuplicateController.new()
      attempt = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}

      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt)
      {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt)
      {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt)

      stats = SimulationDuplicateController.get_stats(controller)
      assert stats == %{duplicates_skipped: 2}
    end
  end

  describe "get_detailed_stats/1" do
    test "returns detailed stats for controller with mixed attempts" do
      controller = SimulationDuplicateController.new()
      attempt1 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      # duplicate
      attempt2 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
      # unique
      attempt3 = %{main: [2, 8, 24, 35, 49], euro: [4, 10]}

      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt1)
      {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt2)
      {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt3)

      stats = SimulationDuplicateController.get_detailed_stats(controller)

      assert stats.duplicates_skipped == 1
      assert stats.unique_attempts == 2
      assert stats.total_attempts == 3
      assert stats.duplicate_ratio == 0.5
    end

    test "handles division by zero for duplicate ratio" do
      controller = SimulationDuplicateController.new()
      stats = SimulationDuplicateController.get_detailed_stats(controller)

      assert stats.duplicates_skipped == 0
      assert stats.unique_attempts == 0
      assert stats.total_attempts == 0
      assert stats.duplicate_ratio == 0.0
    end
  end
end
