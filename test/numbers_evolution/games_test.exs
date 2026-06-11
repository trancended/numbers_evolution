defmodule NumbersEvolution.GamesTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Games

  test "supports eurojackpot and lotto" do
    assert Games.ids() == ["eurojackpot", "lotto"]
    assert Games.default_id() == "eurojackpot"
    assert Games.supported?("lotto")
    refute Games.supported?("multi_multi")
  end

  test "eurojackpot config matches the historical constants" do
    game = Games.get!("eurojackpot")

    assert game.main == %{count: 5, min: 1, max: 50, low_max: 25}
    assert game.bonus == %{count: 2, min: 1, max: 12}
    assert map_size(game.prize_tiers) == 12
    assert game.prize_tiers[{5, 2}] == 1
    assert game.vip.pool_main == 25
    assert game.vip.pool_bonus == 6
    assert game.search_space == 139_838_160
    assert Games.has_bonus?("eurojackpot")
  end

  test "lotto config defines 6 of 49 without bonus numbers" do
    game = Games.get!("lotto")

    assert game.main == %{count: 6, min: 1, max: 49, low_max: 25}
    assert game.bonus.count == 0
    assert game.prize_tiers == %{{6, 0} => 1, {5, 0} => 2, {4, 0} => 3, {3, 0} => 4}

    assert game.vip == %{
             pool_main: 25,
             pool_bonus: 0,
             parity_odd: 3,
             parity_even: 3,
             blacklist_main: 24,
             blacklist_bonus: 0
           }

    # C(49,6)
    assert game.search_space == 13_983_816
    refute Games.has_bonus?("lotto")
  end

  test "select_options returns label/id pairs for forms" do
    assert Games.select_options() == [{"Eurojackpot", "eurojackpot"}, {"Lotto", "lotto"}]
  end

  test "importable games include both eurojackpot and lotto" do
    assert Enum.map(Games.importable(), & &1.id) == ["eurojackpot", "lotto"]
  end
end
