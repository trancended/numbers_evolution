defmodule NumbersEvolution.ExperimentsTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Experiments
  alias NumbersEvolution.Games
  alias NumbersEvolution.Simulations.Estimator

  @game Games.get!("eurojackpot")
  @draws [
    %{main: [3, 17, 24, 38, 45], euro: [2, 9]},
    %{main: [1, 12, 23, 34, 44], euro: [1, 7]},
    %{main: [5, 15, 25, 35, 40], euro: [3, 11]}
  ]

  describe "backtest/4" do
    test "a random generator's EV tracks the analytic baseline" do
      res =
        Experiments.backtest(Experiments.random_generator(@game), @draws, @game,
          attempts: 200_000,
          seed: {1, 2, 3}
        )

      assert res.summary.draws == 3
      assert_in_delta res.summary.ev_mean, Estimator.baseline(@game).expected_value, 3.0
      assert res.summary.robustness > 0.0 and res.summary.robustness <= 1.0
      assert res.summary.ev_p10 <= res.summary.ev_p50
      assert res.summary.ev_p50 <= res.summary.ev_p90
    end

    test "a generator that always plays the target wins every attempt" do
      target = hd(@draws)
      always = fn -> %{main: target.main, euro: target.euro} end
      res = Experiments.backtest(always, [target], @game, attempts: 100)
      pd = hd(res.per_draw)

      assert pd.expected_value > 1_000_000
      assert pd.attempts_to_jackpot.point <= 1.5
    end
  end

  describe "helpers" do
    test "train_test_split partitions by fraction" do
      {train, test} = Experiments.train_test_split(Enum.to_list(1..10), 0.7)
      assert length(train) == 7
      assert length(test) == 3
    end

    test "normalize_target handles the draw numbers shape" do
      target =
        Experiments.normalize_target(%{
          numbers: %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [6, 7]}
        })

      assert target == %{main: [1, 2, 3, 4, 5], euro: [6, 7]}
    end
  end
end
