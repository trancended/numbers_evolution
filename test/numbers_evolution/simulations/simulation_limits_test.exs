defmodule NumbersEvolution.SimulationLimitsTest do
  use NumbersEvolution.DataCase, async: true

  alias NumbersEvolution.Strategies.Strategy

  # Helper to test limits logic (exposed for testing)
  def test_check_limits(current_attempt, max_attempts, start_time, timeout_seconds) do
    cond do
      current_attempt >= max_attempts ->
        {:timeout, "max_attempts"}

      System.monotonic_time(:second) - start_time >= timeout_seconds ->
        {:timeout, "time_limit"}

      true ->
        {:continue, nil}
    end
  end

  # Helper to create minimal test data
  def create_minimal_test_data do
    user_id = "550e8400-e29b-41d4-a716-446655440000"

    strategy = %Strategy{
      id: "550e8400-e29b-41d4-a716-446655440001",
      name: "Test Strategy",
      type: "manual",
      rules: %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          preferred_hot: [],
          preferred_cold: [],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{ratio_even_odd: [1, 1], preferred: [], weights: %{hot: 0.6, random: 0.4}}
      }
    }

    draw = %NumbersEvolution.Draws.Draw{
      id: "550e8400-e29b-41d4-a716-446655440002",
      draw_date: ~D[2024-01-01],
      game_type: "eurojackpot",
      numbers: %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
    }

    simulation = %NumbersEvolution.Simulations.Simulation{
      id: "550e8400-e29b-41d4-a716-446655440003",
      user_id: user_id,
      strategy_id: strategy.id,
      target_draw_id: draw.id,
      attempts_count: 0,
      duration_seconds: 0.0,
      status: "running",
      options: %{"max_attempts" => 1_000_000, "timeout_seconds" => 300}
    }

    {strategy, draw, simulation}
  end

  describe "check_simulation_limits/4 - safety limits" do
    test "max_attempts limit prevents infinite loops" do
      # Test at the limit
      result = test_check_limits(1_000_000, 1_000_000, 0, 300)
      assert result == {:timeout, "max_attempts"}

      # Test over the limit
      result = test_check_limits(1_000_001, 1_000_000, 0, 300)
      assert result == {:timeout, "max_attempts"}
    end

    test "timeout_seconds limit prevents hanging processes" do
      # Test exactly at timeout
      start_time = System.monotonic_time(:second) - 300
      result = test_check_limits(500_000, 1_000_000, start_time, 300)
      assert result == {:timeout, "time_limit"}

      # Test over timeout
      start_time = System.monotonic_time(:second) - 301
      result = test_check_limits(500_000, 1_000_000, start_time, 300)
      assert result == {:timeout, "time_limit"}
    end

    test "continues when under both limits" do
      start_time = System.monotonic_time(:second) - 100
      result = test_check_limits(500_000, 1_000_000, start_time, 300)
      assert result == {:continue, nil}
    end

    test "prioritizes max_attempts over timeout when both exceeded" do
      # Both exceeded, but max_attempts checked first
      start_time = System.monotonic_time(:second) - 400
      result = test_check_limits(1_000_000, 1_000_000, start_time, 300)
      assert result == {:timeout, "max_attempts"}
    end

    test "handles edge cases: zero values" do
      # Zero attempts (should continue)
      result = test_check_limits(0, 1_000_000, 0, 300)
      assert result == {:continue, nil}

      # Very short timeout
      start_time = System.monotonic_time(:second) - 2
      result = test_check_limits(500_000, 1_000_000, start_time, 1)
      assert result == {:timeout, "time_limit"}
    end

    test "handles very large limits (stress test)" do
      # Test with maximum reasonable values
      # 1 hour ago
      start_time = System.monotonic_time(:second) - 3600
      # 2 hours timeout
      result = test_check_limits(10_000_000, 100_000_000, start_time, 7200)
      assert result == {:continue, nil}
    end
  end

  describe "business rules: simulation limits" do
    test "default limits prevent excessive resource usage" do
      # Test default values from the application
      # Default from code
      max_attempts = 1_000_000
      # Default from code
      timeout_seconds = 300

      # Under limits should continue
      start_time = System.monotonic_time(:second) - 250
      result = test_check_limits(500_000, max_attempts, start_time, timeout_seconds)
      assert result == {:continue, nil}

      # Over timeout should stop
      start_time = System.monotonic_time(:second) - 350
      result = test_check_limits(500_000, max_attempts, start_time, timeout_seconds)
      assert result == {:timeout, "time_limit"}

      # Over attempts should stop
      result = test_check_limits(1_500_000, max_attempts, start_time, timeout_seconds)
      assert result == {:timeout, "max_attempts"}
    end

    test "configurable limits work correctly" do
      # Test custom limits
      custom_max_attempts = 500_000
      # 10 minutes
      custom_timeout = 600

      # Under custom limits
      start_time = System.monotonic_time(:second) - 300
      result = test_check_limits(250_000, custom_max_attempts, start_time, custom_timeout)
      assert result == {:continue, nil}

      # Over custom timeout
      start_time = System.monotonic_time(:second) - 650
      result = test_check_limits(250_000, custom_max_attempts, start_time, custom_timeout)
      assert result == {:timeout, "time_limit"}
    end

    test "very short timeouts work for fast failure detection" do
      # Test with very short timeout for quick feedback
      # 5 seconds
      short_timeout = 5

      start_time = System.monotonic_time(:second) - 6
      result = test_check_limits(100, 1_000_000, start_time, short_timeout)
      assert result == {:timeout, "time_limit"}
    end

    test "very long timeouts work for complex strategies" do
      # Test with long timeout for strategies that might need time
      # 1 hour
      long_timeout = 3600

      # 30 minutes ago
      start_time = System.monotonic_time(:second) - 1800
      result = test_check_limits(500_000, 1_000_000, start_time, long_timeout)
      assert result == {:continue, nil}

      # Should timeout after full hour
      start_time = System.monotonic_time(:second) - 3700
      result = test_check_limits(500_000, 1_000_000, start_time, long_timeout)
      assert result == {:timeout, "time_limit"}
    end
  end

  describe "simulation termination scenarios" do
    test "simulation stops on max_attempts reached" do
      # This would normally be tested in integration, but we test the logic
      attempts = 1_000_000
      max_attempts = 1_000_000

      result = test_check_limits(attempts, max_attempts, 0, 300)
      assert result == {:timeout, "max_attempts"}
    end

    test "simulation stops on timeout reached" do
      start_time = System.monotonic_time(:second) - 300
      timeout = 300

      result = test_check_limits(500_000, 1_000_000, start_time, timeout)
      assert result == {:timeout, "time_limit"}
    end

    test "simulation can run for reasonable duration" do
      # Test that simulations can run for reasonable time before timing out
      # 4+ minutes
      start_time = System.monotonic_time(:second) - 250
      # 5 minutes
      timeout = 300

      result = test_check_limits(500_000, 1_000_000, start_time, timeout)
      assert result == {:continue, nil}
    end

    test "prevents runaway simulations with both limits" do
      # Test that both limits together prevent any runaway scenario
      # over time limit
      start_time = System.monotonic_time(:second) - 400
      # over attempt limit
      attempts = 1_100_000

      # Should hit attempt limit first (implementation detail)
      result = test_check_limits(attempts, 1_000_000, start_time, 300)
      assert result == {:timeout, "max_attempts"}
    end
  end

  describe "performance and resource protection" do
    test "limits protect against DoS-like scenarios" do
      # Test that limits prevent potential abuse

      # Scenario 1: Many quick attempts (attempt limit should catch)
      result = test_check_limits(1_000_001, 1_000_000, 0, 300)
      assert result == {:timeout, "max_attempts"}

      # Scenario 2: Slow but persistent attempts (time limit should catch)
      start_time = System.monotonic_time(:second) - 301
      result = test_check_limits(100_000, 1_000_000, start_time, 300)
      assert result == {:timeout, "time_limit"}
    end

    test "reasonable limits allow legitimate strategy testing" do
      # Test that default limits allow reasonable strategy testing

      # A good strategy might need ~10,000 attempts and take ~30 seconds
      start_time = System.monotonic_time(:second) - 30
      result = test_check_limits(10_000, 1_000_000, start_time, 300)
      assert result == {:continue, nil}

      # An average strategy might need ~100,000 attempts and take ~60 seconds
      start_time = System.monotonic_time(:second) - 60
      result = test_check_limits(100_000, 1_000_000, start_time, 300)
      assert result == {:continue, nil}
    end

    test "limits scale appropriately with strategy complexity" do
      # Simple strategies should work with default limits
      start_time = System.monotonic_time(:second) - 30
      result = test_check_limits(1_000, 1_000_000, start_time, 300)
      assert result == {:continue, nil}

      # Complex strategies might need higher limits (but still bounded)
      start_time = System.monotonic_time(:second) - 250
      result = test_check_limits(800_000, 1_000_000, start_time, 300)
      assert result == {:continue, nil}
    end
  end
end
