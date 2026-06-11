defmodule NumbersEvolution.AnalyticsTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Analytics
  alias NumbersEvolution.Simulations.Simulation
  alias NumbersEvolution.Strategies.Strategy

  describe "comb/2" do
    test "computes binomial coefficients" do
      assert Analytics.comb(50, 5) == 2_118_760
      assert Analytics.comb(12, 2) == 66
      assert Analytics.comb(25, 5) == 53_130
      assert Analytics.comb(5, 5) == 1
      assert Analytics.comb(5, 0) == 1
      assert Analytics.comb(3, 5) == 0
    end

    test "full search space is C(50,5) * C(12,2)" do
      assert Analytics.full_search_space() == 2_118_760 * 66
    end
  end

  describe "search_space_for_options/1" do
    test "standard options give the full space" do
      assert Analytics.search_space_for_options(%{}) == 139_838_160
      assert Analytics.search_space_for_options(%{"half_random_mode" => true}) == 139_838_160
    end

    test "vip1 mode gives the half-pool space" do
      assert Analytics.search_space_for_options(%{"vip1_mode" => true}) ==
               Analytics.comb(25, 5) * Analytics.comb(6, 2)
    end

    test "auto-blacklist uses stored sizes" do
      options = %{"vip2_blacklist" => %{"main_size" => 35, "euro_size" => 8}}

      assert Analytics.search_space_for_options(options) ==
               Analytics.comb(15, 5) * Analytics.comb(4, 2)
    end

    test "legacy blacklists without sizes fall back to list lengths" do
      options = %{
        "vip2_blacklist" => %{
          "main_blacklist" => Enum.to_list(1..25),
          "euro_blacklist" => Enum.to_list(1..6)
        }
      }

      assert Analytics.search_space_for_options(options) ==
               Analytics.comb(25, 5) * Analytics.comb(6, 2)
    end
  end

  describe "simulation_mode/1" do
    test "detects modes from options flags" do
      assert Analytics.simulation_mode(%{"vip2_blacklist" => %{}}) == :auto_blacklist
      assert Analytics.simulation_mode(%{"vip1_mode" => true}) == :vip1
      assert Analytics.simulation_mode(%{"half_random_mode" => true}) == :half_random
      assert Analytics.simulation_mode(%{}) == :standard
    end
  end

  describe "summarize_group/2" do
    test "aggregates success stats, search space, and tier rates" do
      strategy = %Strategy{id: "s1", name: "Test VIP2"}

      options = %{"vip2_blacklist" => %{"main_size" => 25, "euro_size" => 6}}

      sims = [
        simulation(strategy, "success", 100_000, 10.0, options, %{"12" => 500, "11" => 100}),
        simulation(strategy, "success", 300_000, 30.0, options, %{"12" => 1500}),
        simulation(strategy, "max_attempts_reached", 1_000_000, 100.0, options, %{})
      ]

      stats = Analytics.summarize_group(:auto_blacklist, sims)

      assert stats.simulations_count == 3
      assert stats.success_count == 2
      assert_in_delta stats.success_rate, 2 / 3, 0.001
      assert stats.min_attempts == 100_000
      assert stats.max_attempts == 300_000
      assert stats.median_attempts == 200_000.0
      assert stats.search_space == Analytics.comb(25, 5) * Analytics.comb(6, 2)
      assert_in_delta stats.expected_vs_actual, 200_000 / 796_950, 0.001
      # 2000 tier-12 hits across 1.4M attempts -> ~142.86 per 100k
      assert_in_delta stats.tiers_per_100k[12], 2000 * 100_000 / 1_400_000, 0.01
    end

    test "handles groups with no successes" do
      strategy = %Strategy{id: "s2", name: "Always fails"}
      sims = [simulation(strategy, "timeout", 1_000_000, 100.0, %{}, %{})]

      stats = Analytics.summarize_group(:standard, sims)

      assert stats.success_count == 0
      assert stats.median_attempts == nil
      assert stats.expected_vs_actual == nil
      assert stats.search_space == Analytics.full_search_space()
    end
  end

  defp simulation(strategy, status, attempts, duration, options, prize_tiers) do
    %Simulation{
      strategy: strategy,
      status: status,
      attempts_count: attempts,
      duration_seconds: duration,
      options: options,
      result: %NumbersEvolution.Simulations.SimulationResult{prize_tiers: prize_tiers}
    }
  end
end
