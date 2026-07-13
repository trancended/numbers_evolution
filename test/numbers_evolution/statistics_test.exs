defmodule NumbersEvolution.StatisticsTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Statistics

  describe "descriptive stats" do
    test "mean/variance/stddev" do
      assert Statistics.mean([]) == nil
      assert Statistics.mean([2, 4, 6]) == 4.0
      assert Statistics.variance([]) == nil
      assert Statistics.variance([5]) == 0.0
      # sample variance of [2,4,6] = 4.0
      assert Statistics.variance([2, 4, 6]) == 4.0
      assert Statistics.stddev([2, 4, 6]) == 2.0
    end

    test "percentile with linear interpolation" do
      assert Statistics.percentile([], 0.5) == nil
      assert Statistics.percentile([1, 2, 3, 4], 0.5) == 2.5
      assert Statistics.percentile([1, 2, 3, 4], 0.0) == 1.0
      assert Statistics.percentile([1, 2, 3, 4], 1.0) == 4.0
      assert Statistics.median([10, 2, 8, 4]) == 6.0
    end
  end

  describe "wilson_interval/3" do
    test "zero trials yields maximal ignorance" do
      assert Statistics.wilson_interval(0, 0) == {0.0, 0.0, 1.0}
    end

    test "point estimate is successes/trials and bounds bracket it" do
      {p_hat, low, high} = Statistics.wilson_interval(50, 1000)
      assert p_hat == 0.05
      assert low < p_hat and p_hat < high
      assert low >= 0.0 and high <= 1.0
    end

    test "bounds stay in [0,1] for extreme proportions" do
      {_p, low, high} = Statistics.wilson_interval(1, 5)
      assert low >= 0.0
      assert high <= 1.0
    end
  end

  describe "rule_of_three/1" do
    test "upper bound on rate for zero observed events" do
      assert Statistics.rule_of_three(1_000_000) == 3.0e-6
    end
  end

  describe "hypothesis testing" do
    test "normal_cdf matches known values" do
      assert_in_delta Statistics.normal_cdf(0.0), 0.5, 1.0e-6
      assert_in_delta Statistics.normal_cdf(1.959963984540054), 0.975, 1.0e-3
      assert_in_delta Statistics.normal_cdf(-1.959963984540054), 0.025, 1.0e-3
    end

    test "identical proportions are not significant" do
      {z, p} = Statistics.two_proportion_z(100, 1000, 100, 1000)
      assert z == 0.0
      assert_in_delta p, 1.0, 1.0e-6
    end

    test "clearly different proportions are significant" do
      {_z, p} = Statistics.two_proportion_z(100, 1000, 300, 1000)
      assert p < 0.001
    end
  end

  describe "bootstrap_ci/4" do
    test "empty sample returns nil" do
      assert Statistics.bootstrap_ci([], &Statistics.mean/1) == nil
    end

    test "brackets the mean of a stable sample" do
      :rand.seed(:exsss, {1, 2, 3})
      sample = for _ <- 1..200, do: 100 + :rand.uniform(10)
      {point, low, high} = Statistics.bootstrap_ci(sample, &Statistics.mean/1, 500)
      assert low <= point and point <= high
    end
  end
end
