defmodule NumbersEvolution.Simulations.EstimatorTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Analytics
  alias NumbersEvolution.Games
  alias NumbersEvolution.Simulations.Estimator

  @euro Games.get!("eurojackpot")
  @lotto Games.get!("lotto")

  describe "exact_tier/3" do
    test "maps matches to the single best prize tier" do
      assert Estimator.exact_tier(@euro, 5, 2) == 1
      assert Estimator.exact_tier(@euro, 4, 1) == 5
      assert Estimator.exact_tier(@euro, 2, 1) == 12
    end

    test "returns nil when no prize is won" do
      assert Estimator.exact_tier(@euro, 2, 0) == nil
      assert Estimator.exact_tier(@euro, 1, 1) == nil
    end
  end

  describe "baseline_match_probs/1" do
    test "eurojackpot joint probabilities sum to 1" do
      total = @euro |> Estimator.baseline_match_probs() |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-9
    end

    test "jackpot probability equals 1 / full search space" do
      probs = Estimator.baseline_match_probs(@euro)
      assert_in_delta probs[{5, 2}], 1.0 / Analytics.full_search_space(), 1.0e-18
    end

    test "lotto (no euro) sums to 1 and jackpot is 1 / C(49,6)" do
      probs = Estimator.baseline_match_probs(@lotto)
      assert_in_delta Map.values(probs) |> Enum.sum(), 1.0, 1.0e-9
      assert_in_delta probs[{6, 0}], 1.0 / Analytics.comb(49, 6), 1.0e-15
    end
  end

  describe "baseline/1" do
    test "attempts to jackpot equals the full search space" do
      base = Estimator.baseline(@euro)
      assert_in_delta base.attempts_to_jackpot_point, Analytics.full_search_space() * 1.0, 1.0
    end

    test "expected value is negative (house edge)" do
      assert Estimator.baseline(@euro).expected_value < 0.0
    end
  end

  describe "estimate/3" do
    @n 1_000_000
    @hist %{{5, 2} => 10, {3, 0} => 2000, {0, 0} => 997_990}

    test "cumulative tier rates match engine-style counting" do
      res = Estimator.estimate(@hist, @n, "eurojackpot")
      assert_in_delta res.tier_rates[1].rate, 10 / @n, 1.0e-12
      # tier 10 (3+0) also counts the 5+2 rows (5 >= 3): 2000 + 10
      assert res.tier_rates[10].count == 2010
      assert res.tier_rates[1].ci_low <= res.tier_rates[1].rate
      assert res.tier_rates[1].rate <= res.tier_rates[1].ci_high
    end

    test "exact tier rates do not double-count" do
      res = Estimator.estimate(@hist, @n, "eurojackpot")
      assert_in_delta res.exact_tier_rates[1], 10 / @n, 1.0e-12
      assert_in_delta res.exact_tier_rates[10], 2000 / @n, 1.0e-12
    end

    test "attempts to jackpot inverts the observed rate with an ordered CI" do
      res = Estimator.estimate(@hist, @n, "eurojackpot")
      assert_in_delta res.attempts_to_jackpot.point, 100_000.0, 1.0
      assert res.attempts_to_jackpot.low <= res.attempts_to_jackpot.point
      assert res.attempts_to_jackpot.point <= res.attempts_to_jackpot.high
    end

    test "zero jackpots yields a rule-of-three lower bound, not a point" do
      res = Estimator.estimate(%{{3, 0} => 500, {0, 0} => 999_500}, @n, "eurojackpot")
      assert res.attempts_to_jackpot.point == nil
      assert_in_delta res.attempts_to_jackpot.low, @n / 3.0, 1.0
      assert res.attempts_to_jackpot.note == :zero_events_lower_bound
    end

    test "reports EV, ROI and delta against baseline" do
      res = Estimator.estimate(@hist, @n, "eurojackpot")
      assert is_float(res.expected_value)
      assert is_float(res.roi)
      assert_in_delta res.ev_delta, res.expected_value - res.baseline.expected_value, 1.0e-9
    end
  end
end
