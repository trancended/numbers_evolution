defmodule NumbersEvolution.Simulations.GoldenMeanTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Simulations.GoldenMean
  alias NumbersEvolution.Simulations.Optimizer.Analytic
  alias NumbersEvolution.Simulations.Probe

  describe "Probe" do
    test "analytic probe is monotonically decreasing in blacklist size" do
      p = Probe.make_analytic_probe("eurojackpot", 0)
      assert p.(0) > p.(10)
      assert p.(10) > p.(20)
      assert p.(20) > p.(30)
    end

    test "k=0 probe equals the full search space" do
      assert Probe.make_analytic_probe("eurojackpot", 0).(0) == 139_838_160
    end
  end

  describe "Analytic (ALG-1)" do
    test "calibrates within 2x of the setpoint across scales" do
      for target <- [100, 1000, 10_000, 1_000_000] do
        {:ok, sol} = Analytic.solve(target, %{game: "eurojackpot"})
        assert abs(sol.metric - target) / target <= 1.0
      end
    end
  end

  describe "GoldenMean.calibrate/2 (ALG-2 feedback)" do
    test "hits ~100 attempts and matches a brute-force argmin" do
      rec = GoldenMean.calibrate(100, game: "eurojackpot")
      assert abs(rec.expected_attempts - 100) / 100 <= 1.0
      assert rec.iterations <= 64

      brute =
        0..Probe.max_main_blacklist("eurojackpot")
        |> Enum.min_by(&abs(Probe.search_space(&1, 0, "eurojackpot") - 100))

      assert rec.main_blacklist_size == brute
    end

    test "larger setpoint needs less blacklist" do
      small = GoldenMean.calibrate(100, game: "eurojackpot")
      large = GoldenMean.calibrate(1_000_000, game: "eurojackpot")
      assert large.main_blacklist_size < small.main_blacklist_size
    end

    test "works for lotto (no euro numbers)" do
      rec = GoldenMean.calibrate(100, game: "lotto")
      assert abs(rec.expected_attempts - 100) / 100 <= 1.0
    end

    test "feedback loop converges even with a biased probe" do
      biased = fn k -> round(Probe.search_space(k, 0, "eurojackpot") * 0.6) end
      rec = GoldenMean.calibrate(100, game: "eurojackpot", probe: biased)
      assert abs(rec.expected_attempts - 100) / 100 <= 1.0
    end

    test "to_options/1 bridges into engine auto-blacklist inputs" do
      rec = GoldenMean.calibrate(100, game: "eurojackpot")
      opts = GoldenMean.to_options(rec)
      assert opts["auto_blacklist"] == true
      assert opts["auto_blacklist_main_size"] == rec.main_blacklist_size
      assert opts["auto_blacklist_euro_size"] == rec.euro_blacklist_size
    end
  end
end
