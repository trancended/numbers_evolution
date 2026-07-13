defmodule NumbersEvolution.Simulations.EnginesTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Analytics
  alias NumbersEvolution.Games
  alias NumbersEvolution.Simulations.Algorithm.{Annealing, QuasiRandom}
  alias NumbersEvolution.Simulations.Optimizer.Bayesian

  @euro Games.get!("eurojackpot")
  @lotto Games.get!("lotto")
  @target %{main: [3, 17, 24, 38, 45], euro: [2, 9]}

  describe "Annealing (ALG-6)" do
    test "reaches the exact target far faster than blind random" do
      :rand.seed(:exsss, {5, 5, 5})
      results = for _ <- 1..20, do: Annealing.search(@target, @euro, max_steps: 5000)

      assert Enum.all?(results, & &1.hit?)
      avg = results |> Enum.map(& &1.steps) |> then(&(Enum.sum(&1) / length(&1)))
      assert avg < 2000

      assert hd(results).combo == %{main: Enum.sort(@target.main), euro: Enum.sort(@target.euro)}
    end
  end

  describe "QuasiRandom (ALG-7)" do
    test "produces valid, low-collision combinations" do
      combos = QuasiRandom.take(2000, @euro)

      assert Enum.all?(combos, fn c ->
               length(Enum.uniq(c.main)) == 5 and Enum.all?(c.main, &(&1 in 1..50)) and
                 length(Enum.uniq(c.euro)) == 2 and Enum.all?(c.euro, &(&1 in 1..12))
             end)

      uniq = combos |> Enum.map(&{c_key(&1)}) |> Enum.uniq() |> length()
      assert uniq > 1990
    end

    test "unrank is ascending, distinct, and round-trips" do
      sample = QuasiRandom.unrank(12_345, 5)
      assert sample == Enum.sort(Enum.uniq(sample))
      assert length(sample) == 5

      rank =
        sample
        |> Enum.with_index(1)
        |> Enum.reduce(0, fn {c, j}, acc -> acc + Analytics.comb(c, j) end)

      assert rank == 12_345
    end

    test "supports games without euro numbers" do
      combos = QuasiRandom.take(500, @lotto)
      assert Enum.all?(combos, fn c -> length(c.main) == 6 and c.euro == [] end)
    end
  end

  describe "Bayesian (ALG-5)" do
    test "minimizes the sphere sample-efficiently" do
      sphere = fn v -> Enum.reduce(v, 0.0, fn x, acc -> acc + x * x end) end

      sol =
        Bayesian.minimize(sphere,
          bounds: List.duplicate({-5.0, 5.0}, 3),
          max_iter: 70,
          seed: {3, 1, 4}
        )

      assert sol.score < 0.5
      assert sol.iterations <= 70
    end
  end

  defp c_key(c), do: {Enum.sort(c.main), Enum.sort(c.euro)}
end
