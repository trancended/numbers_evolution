defmodule NumbersEvolution.Simulations.AutoBlacklistTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Simulations
  alias NumbersEvolution.Strategies.Generator
  alias NumbersEvolution.Strategies.Strategy

  @target_main [2, 11, 24, 33, 46]
  @target_euro [5, 8]

  describe "Simulations.generate_auto_blacklist/4" do
    test "never includes target numbers, across many random generations" do
      for _ <- 1..100 do
        blacklist = Simulations.generate_auto_blacklist(@target_main, @target_euro, 25, 6)

        assert Enum.all?(@target_main, &(&1 not in blacklist["main_blacklist"]))
        assert Enum.all?(@target_euro, &(&1 not in blacklist["euro_blacklist"]))
      end
    end

    test "respects requested sizes and stores them" do
      blacklist = Simulations.generate_auto_blacklist(@target_main, @target_euro, 35, 8)

      assert length(blacklist["main_blacklist"]) == 35
      assert length(blacklist["euro_blacklist"]) == 8
      assert blacklist["main_size"] == 35
      assert blacklist["euro_size"] == 8
    end

    test "generates unique numbers within valid ranges" do
      blacklist = Simulations.generate_auto_blacklist(@target_main, @target_euro, 45, 10)

      main = blacklist["main_blacklist"]
      euro = blacklist["euro_blacklist"]

      assert length(Enum.uniq(main)) == 45
      assert length(Enum.uniq(euro)) == 10
      assert Enum.all?(main, &(&1 in 1..50))
      assert Enum.all?(euro, &(&1 in 1..12))
    end

    test "supports size 0 (no exclusions)" do
      blacklist = Simulations.generate_auto_blacklist(@target_main, @target_euro, 0, 0)

      assert blacklist["main_blacklist"] == []
      assert blacklist["euro_blacklist"] == []
    end
  end

  describe "Generator.prepare_vip2_pools/1" do
    test "splits available numbers by parity and excludes blacklisted" do
      blacklist = %{main_blacklist: Enum.to_list(1..25), euro_blacklist: [1, 2, 3, 4, 5, 6]}
      pools = Generator.prepare_vip2_pools(blacklist)

      assert pools.main_available == Enum.to_list(26..50)
      assert pools.euro_available == Enum.to_list(7..12)
      assert pools.main_odd == Enum.filter(26..50, &(rem(&1, 2) == 1))
      assert pools.main_even == Enum.filter(26..50, &(rem(&1, 2) == 0))
    end
  end

  describe "Generator.generate_numbers/2 with configurable blacklist sizes" do
    test "generated numbers never come from a large (VIP3-style) blacklist" do
      blacklist_map =
        Simulations.generate_auto_blacklist(@target_main, @target_euro, 35, 8)

      blacklist = %{
        main_blacklist: blacklist_map["main_blacklist"],
        euro_blacklist: blacklist_map["euro_blacklist"]
      }

      strategy = %Strategy{id: "test", name: "VIP3 Test", type: "manual", rules: nil}

      for _ <- 1..50 do
        {:ok, result} = Generator.generate_numbers(strategy, vip2_blacklist: blacklist)

        assert length(result.main) == 5
        assert length(result.euro) == 2
        assert Enum.all?(result.main, &(&1 not in blacklist.main_blacklist))
        assert Enum.all?(result.euro, &(&1 not in blacklist.euro_blacklist))
      end
    end

    test "precomputed pools yield the same exclusion guarantees" do
      blacklist = %{
        main_blacklist: Enum.to_list(16..50),
        euro_blacklist: Enum.to_list(5..12)
      }

      blacklist_with_pools = Map.put(blacklist, :pools, Generator.prepare_vip2_pools(blacklist))
      strategy = %Strategy{id: "test", name: "VIP3 Test", type: "manual", rules: nil}

      for _ <- 1..50 do
        {:ok, result} =
          Generator.generate_numbers(strategy, vip2_blacklist: blacklist_with_pools)

        assert Enum.all?(result.main, &(&1 in 1..15))
        assert Enum.all?(result.euro, &(&1 in 1..4))
      end
    end
  end
end
