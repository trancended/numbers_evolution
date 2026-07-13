defmodule NumbersEvolution.Simulations.MetaOptimizerTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Simulations.Optimizer.{Bandit, Genetic, NelderMead}

  defp sphere(v), do: Enum.reduce(v, 0.0, fn x, acc -> acc + x * x end)

  defp rosenbrock([x, y]) do
    a = 1.0 - x
    b = y - x * x
    a * a + 100.0 * b * b
  end

  describe "Genetic (ALG-3)" do
    test "minimizes the sphere function near 0" do
      sol =
        Genetic.minimize(&sphere/1,
          bounds: List.duplicate({-5.0, 5.0}, 5),
          seed: {1, 2, 3},
          generations: 80,
          population: 60
        )

      assert sol.score < 0.05
    end

    test "is reproducible for a fixed seed" do
      opts = [bounds: [{-3.0, 3.0}, {-3.0, 3.0}], seed: {9, 9, 9}, generations: 40]
      a = Genetic.minimize(&rosenbrock/1, opts)
      b = Genetic.minimize(&rosenbrock/1, opts)
      assert a.params == b.params
      assert a.score == b.score
    end
  end

  describe "NelderMead (ALG-4)" do
    test "converges to the sphere minimum" do
      sol = NelderMead.minimize(&sphere/1, start: [3.0, -2.0, 4.0, 1.0], max_iter: 400)
      assert sol.score < 1.0e-6
      assert sol.converged
    end

    test "solves Rosenbrock to (1,1)" do
      sol = NelderMead.minimize(&rosenbrock/1, start: [-1.2, 1.0], max_iter: 1000, tol: 1.0e-10)
      assert sol.score < 1.0e-4
    end
  end

  describe "Bandit (ALG-8)" do
    test "identifies and exploits the best arm (no-regret)" do
      :rand.seed(:exsss, {42, 42, 42})
      true_means = %{a: 0.2, b: 0.5, c: 0.85}
      state = Bandit.new(Map.keys(true_means))

      state =
        Enum.reduce(1..3000, state, fn _i, st ->
          arm = Bandit.select(st)
          r = if :rand.uniform() < true_means[arm], do: 1.0, else: 0.0
          Bandit.reward(st, arm, r)
        end)

      stats = Bandit.stats(state)
      assert Bandit.best(state) == :c
      assert stats[:c].pulls > 0.6 * 3000
      assert stats[:c].pulls > stats[:a].pulls
    end
  end
end
