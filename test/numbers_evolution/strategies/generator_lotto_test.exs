defmodule NumbersEvolution.Strategies.GeneratorLottoTest do
  use ExUnit.Case, async: true

  alias NumbersEvolution.Strategies.Generator
  alias NumbersEvolution.Strategies.Strategy

  defp test_strategy(overrides \\ %{}) do
    main_overrides = Map.get(overrides, :main_numbers, %{})

    %Strategy{
      id: "test-strategy",
      name: Map.get(overrides, :name, "Test Strategy"),
      type: "manual",
      rules: %{
        main_numbers:
          Map.merge(
            %{
              ratio_even_odd: [2, 3],
              ratio_low_high: [3, 2],
              preferred_hot: [],
              preferred_cold: [],
              blacklist: [],
              weights: %{hot: 0.5, cold: 0.0, random: 0.5}
            },
            main_overrides
          ),
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          preferred: [],
          blacklist: [],
          weights: %{hot: 0.5, random: 0.5}
        }
      }
    }
  end

  describe "standard generation for lotto" do
    test "generates 6 unique main numbers in 1..49 and no euro numbers" do
      strategy = test_strategy()

      for _ <- 1..50 do
        assert {:ok, result} = Generator.generate_numbers(strategy, game: "lotto")
        assert length(result.main) == 6
        assert length(Enum.uniq(result.main)) == 6
        assert Enum.all?(result.main, &(&1 in 1..49))
        assert result.euro == []
      end
    end

    test "eurojackpot-shaped ratios act as minimum counts for lotto" do
      strategy = test_strategy()

      for _ <- 1..50 do
        assert {:ok, result} = Generator.generate_numbers(strategy, game: "lotto")
        even = Enum.count(result.main, &(rem(&1, 2) == 0))
        odd = Enum.count(result.main, &(rem(&1, 2) == 1))
        low = Enum.count(result.main, &(&1 <= 25))
        high = Enum.count(result.main, &(&1 > 25))

        assert even >= 2
        assert odd >= 3
        assert low >= 3
        assert high >= 2
      end
    end

    test "0-ratio targets stay hard exclusions for lotto (only odd numbers)" do
      strategy = test_strategy(%{main_numbers: %{ratio_even_odd: [0, 5]}})

      for _ <- 1..30 do
        assert {:ok, result} = Generator.generate_numbers(strategy, game: "lotto")
        assert Enum.all?(result.main, &(rem(&1, 2) == 1))
      end
    end

    test "blacklist is respected for lotto" do
      blacklist = Enum.to_list(30..49)
      strategy = test_strategy(%{main_numbers: %{blacklist: blacklist, ratio_low_high: [5, 0]}})

      for _ <- 1..30 do
        assert {:ok, result} = Generator.generate_numbers(strategy, game: "lotto")
        assert Enum.all?(result.main, &(&1 not in blacklist))
      end
    end

    test "default game stays eurojackpot (5 main + 2 euro)" do
      strategy = test_strategy()

      assert {:ok, result} = Generator.generate_numbers(strategy)
      assert length(result.main) == 5
      assert length(result.euro) == 2
    end
  end

  describe "half_random_mode for lotto" do
    test "generates 6 main numbers and no euro numbers" do
      strategy = test_strategy()

      assert {:ok, result} =
               Generator.generate_numbers(strategy, game: "lotto", half_random_mode: true)

      assert length(result.main) == 6
      assert Enum.all?(result.main, &(&1 in 1..49))
      assert result.euro == []
    end
  end

  describe "VIP1 for lotto" do
    test "generates a pool of 25 main numbers and no euro pool" do
      assert {:ok, pool} = Generator.generate_vip1_pool("lotto")
      assert length(pool.main_pool) == 25
      assert Enum.all?(pool.main_pool, &(&1 in 1..49))
      assert pool.euro_pool == []
    end

    test "generates 6 numbers from the pool with 3 odd + 3 even when possible" do
      # Pool with plenty of both parities spread across decades
      pool = %{main_pool: [1, 2, 3, 4, 11, 12, 21, 22, 31, 32, 41, 42, 13, 14], euro_pool: []}

      assert {:ok, result} = Generator.generate_vip1_numbers(pool, "lotto")
      assert length(result.main) == 6
      assert Enum.all?(result.main, &(&1 in pool.main_pool))
      assert result.euro == []

      if result.constraints_met do
        assert Enum.count(result.main, &(rem(&1, 2) == 1)) == 3
        assert Enum.count(result.main, &(rem(&1, 2) == 0)) == 3
      end
    end

    test "validate_vip_constraints requires 3 odd + 3 even for lotto" do
      # 3 odd + 3 even, max 2 per decade
      assert :ok = Generator.validate_vip_constraints([1, 2, 13, 14, 25, 26], [], "lotto")

      # 2 odd + 4 even - invalid for lotto
      assert {:error, errors} =
               Generator.validate_vip_constraints([1, 2, 14, 16, 25, 26], [], "lotto")

      assert Enum.any?(errors, &(&1 =~ "3 nieparzyste i 3 parzyste"))
    end

    test "validate_vip_constraints keeps 2 odd + 3 even for eurojackpot" do
      assert :ok = Generator.validate_vip_constraints([1, 2, 13, 14, 26], [1, 2])
    end
  end

  describe "VIP2 for lotto" do
    test "generates numbers from outside the blacklist with no euro numbers" do
      blacklist = %{
        main_blacklist: Enum.to_list(26..49),
        euro_blacklist: []
      }

      strategy = test_strategy()

      assert {:ok, result} = Generator.generate_vip2_numbers(strategy, blacklist, "lotto")
      assert length(result.main) == 6
      assert Enum.all?(result.main, &(&1 in 1..25))
      assert result.euro == []
    end
  end
end
