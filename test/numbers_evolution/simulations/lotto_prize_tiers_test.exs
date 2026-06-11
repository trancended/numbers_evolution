defmodule NumbersEvolution.Simulations.LottoPrizeTiersTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Simulations

  @target %{main_numbers: [1, 2, 3, 4, 5, 6], euro_numbers: []}

  defp tiers(main) do
    Simulations.calculate_all_prize_tiers(%{main: main, euro: []}, @target, "lotto")
  end

  describe "calculate_all_prize_tiers/3 for lotto" do
    test "6 matches hit all tiers including the jackpot (tier 1)" do
      assert Enum.sort(tiers([1, 2, 3, 4, 5, 6])) == [1, 2, 3, 4]
    end

    test "5 matches hit tiers 2-4" do
      assert Enum.sort(tiers([1, 2, 3, 4, 5, 49])) == [2, 3, 4]
    end

    test "4 matches hit tiers 3-4" do
      assert Enum.sort(tiers([1, 2, 3, 4, 48, 49])) == [3, 4]
    end

    test "3 matches hit tier 4 only" do
      assert Enum.sort(tiers([1, 2, 3, 47, 48, 49])) == [4]
    end

    test "2 matches win nothing" do
      assert tiers([1, 2, 46, 47, 48, 49]) == []
    end

    test "0 matches win nothing" do
      assert tiers([44, 45, 46, 47, 48, 49]) == []
    end
  end

  describe "calculate_all_prize_tiers for eurojackpot stays unchanged" do
    test "5+2 hits all 12 tiers" do
      target = %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]}
      generated = %{main: [1, 2, 3, 4, 5], euro: [1, 2]}

      assert Enum.sort(Simulations.calculate_all_prize_tiers(generated, target)) ==
               Enum.to_list(1..12)
    end
  end

  describe "generate_auto_blacklist/5 for lotto" do
    test "samples main blacklist from 1..49 and never blocks targets" do
      target_main = [1, 2, 3, 4, 5, 6]

      for _ <- 1..20 do
        blacklist = Simulations.generate_auto_blacklist(target_main, [], 24, 0, "lotto")

        assert length(blacklist["main_blacklist"]) == 24
        assert blacklist["euro_blacklist"] == []
        assert Enum.all?(blacklist["main_blacklist"], &(&1 in 1..49))
        assert Enum.all?(target_main, &(&1 not in blacklist["main_blacklist"]))
      end
    end

    test "eurojackpot default call keeps the historical ranges" do
      blacklist = Simulations.generate_auto_blacklist([1, 2, 3, 4, 5], [1, 2], 25, 6)

      assert length(blacklist["main_blacklist"]) == 25
      assert length(blacklist["euro_blacklist"]) == 6
      assert Enum.all?(blacklist["main_blacklist"], &(&1 in 1..50))
      assert Enum.all?(blacklist["euro_blacklist"], &(&1 in 1..12))
    end
  end
end
