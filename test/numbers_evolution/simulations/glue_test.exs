defmodule NumbersEvolution.Simulations.GlueTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Games
  alias NumbersEvolution.Simulations.Algorithm.{Annealing, QuasiRandom}
  alias NumbersEvolution.Simulations.{Genome, Mixer, Objective, Probe}
  alias NumbersEvolution.Simulations.Optimizer.Genetic

  @game Games.get!("eurojackpot")

  describe "Objective" do
    test "on-setpoint configs score better under the calibration preset" do
      on = %{expected_attempts: 100, setpoint: 100, roi: -0.9, search_space: 100}
      off = %{expected_attempts: 5000, setpoint: 100, roi: -0.9, search_space: 5000}

      assert Objective.score(on, weights: :calibration) <
               Objective.score(off, weights: :calibration)
    end

    test "bias guard rail penalizes degenerate spaces" do
      assert Objective.bias_penalty(1, 20) > 1000.0
      assert Objective.bias_penalty(5, 20) > Objective.bias_penalty(15, 20)
      assert Objective.bias_penalty(1000, 20) == 0.0
    end
  end

  describe "Genome" do
    test "decodes any vector into a legal strategy parameterization" do
      d = Genome.decode([0.5, -0.3, 1.2, 0.1, -0.5, 20.0], "eurojackpot")

      assert_in_delta d.main_weights.hot + d.main_weights.cold + d.main_weights.random,
                      1.0,
                      1.0e-9

      assert_in_delta d.euro_weights.hot + d.euro_weights.random, 1.0, 1.0e-9
      assert d.main_blacklist_size in 0..Probe.max_main_blacklist("eurojackpot")
    end

    test "to_rules_attrs produces a StrategyRules-shaped map" do
      attrs = Genome.decode([0.0, 0.0, 0.0, 0.0, 0.0, 10.0]) |> Genome.to_rules_attrs()
      assert attrs["euro_numbers"]["ratio_even_odd"] == [1, 1]
      sum = attrs["main_numbers"]["weights"] |> Map.values() |> Enum.sum()
      assert_in_delta sum, 1.0, 0.005
    end
  end

  describe "self-optimization loop (GA + Genome + Objective + Probe)" do
    test "evolves a genome that calibrates near the setpoint" do
      setpoint = 100

      fitness = fn genome ->
        dec = Genome.decode(genome, @game)
        attempts = Probe.search_space(dec.main_blacklist_size, 0, @game)

        Objective.score(
          %{expected_attempts: attempts, setpoint: setpoint, search_space: attempts},
          weights: :calibration
        )
      end

      sol =
        Genetic.minimize(fitness,
          bounds: Genome.bounds(@game),
          seed: {11, 22, 33},
          generations: 60
        )

      best = Genome.decode(sol.params, @game)
      attempts = Probe.search_space(best.main_blacklist_size, 0, @game)
      assert abs(attempts - setpoint) / setpoint <= 1.0
    end
  end

  describe "Mixer" do
    test "mixes engines and self-allocates toward the fastest one" do
      target = %{main: [3, 17, 24, 38, 45], euro: [2, 9]}

      result =
        Mixer.run(
          [
            {:annealing, Annealing, [target: target, seed: {1, 1, 1}]},
            {:quasi, QuasiRandom, []}
          ],
          target,
          @game,
          budget: 20_000,
          seed: {2, 2, 2}
        )

      assert result.hit?
      assert result.winner == :annealing
      assert result.bandit_stats.annealing.mean > result.bandit_stats.quasi.mean
    end
  end
end
