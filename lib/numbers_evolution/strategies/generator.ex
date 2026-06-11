defmodule NumbersEvolution.Strategies.Generator do
  @moduledoc """
  Generates lottery number combinations based on strategy rules.

  Number counts and ranges come from the game configuration
  (`NumbersEvolution.Games`, default: Eurojackpot 5/50 + 2/12, Lotto 6/49).
  The generator applies strategy rules including:
  - Even/odd ratios
  - Low/high ratios (for main numbers)
  - Preferred hot/cold numbers
  - Weighted pool selection (hot/cold/random)

  Strategy ratios are Eurojackpot-shaped (they sum to 5). For games with a
  different main-number count (Lotto: 6) the ratios are treated as minimum
  counts and the extra numbers are unconstrained.

  ## VIP1 Mode

  VIP1 mode is a special simulation type that:
  1. Randomly skips ~50% of numbers (per-game pool sizes) before starting
  2. Validates that the reduced pool can produce the target 1st prize numbers
  3. Applies additional constraints: max 2 numbers per decade and a per-game
     odd/even split (Eurojackpot: 2+3, Lotto: 3+3)
  4. Saves the initial pool with the simulation for reproducibility
  """

  alias NumbersEvolution.Games
  alias NumbersEvolution.Strategies.Strategy

  @doc """
  Generates a combination of numbers according to strategy rules.

  Returns a map with `:main` and `:euro` lists sized per the game passed in
  `opts[:game]` (game id or config, default: Eurojackpot). Games without
  bonus numbers (Lotto) return `euro: []`.

  Validates that:
  - Main numbers are unique and within the game's range
  - Euro numbers are unique and within the game's range (when the game has them)
  - All constraints (even/odd, low/high ratios) are satisfied
  """
  @spec generate_numbers(Strategy.t(), keyword()) ::
          {:ok, %{main: [pos_integer()], euro: [pos_integer()]}}
          | {:error, atom()}
  def generate_numbers(%Strategy{name: name} = strategy, opts \\ []) do
    game = Games.get!(Keyword.get(opts, :game, Games.default_id()))
    half_random_mode = Keyword.get(opts, :half_random_mode, false)
    vip1_mode = Keyword.get(opts, :vip1_mode, false)
    vip1_pool = Keyword.get(opts, :vip1_pool, nil)
    vip2_blacklist = Keyword.get(opts, :vip2_blacklist, nil)
    pools = Keyword.get(opts, :pools, nil)

    cond do
      vip1_mode and vip1_pool != nil ->
        generate_vip1_numbers(vip1_pool, game)

      vip2_blacklist != nil ->
        generate_vip2_numbers(strategy, vip2_blacklist, game)

      String.contains?(name, "Losowo pomin połowę") or half_random_mode ->
        generate_half_random_strategy(strategy, game)

      true ->
        generate_numbers_standard(strategy, pools, game)
    end
  end

  @doc """
  Precomputes hot/cold/random pools for the standard generation path.

  Pools depend only on strategy rules and the game, so simulations can build
  them once and pass them via `opts[:pools]` to `generate_numbers/2` instead
  of rebuilding MapSets on every attempt.
  """
  @spec build_pools(Strategy.t(), String.t() | map()) :: %{main: map(), euro: map()}
  def build_pools(%Strategy{rules: rules}, game \\ Games.default_id()) do
    game = Games.get!(game)

    %{
      main: build_main_pools(rules.main_numbers, game),
      euro: build_euro_pools(rules.euro_numbers, game)
    }
  end

  defp generate_numbers_standard(%Strategy{rules: rules}, pools, game) do
    main_numbers = generate_main_numbers(rules.main_numbers, pools[:main], game)
    euro_numbers = generate_euro_numbers(rules.euro_numbers, pools[:euro], game)

    result = %{main: Enum.sort(main_numbers), euro: Enum.sort(euro_numbers)}

    case validate_result(result, rules, game) do
      :ok -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  # Special strategy: randomly omit half numbers, then select a per-game odd/even
  # split with max 2 per decade
  defp generate_half_random_strategy(_strategy, game) do
    with {:ok, main_numbers} <- generate_half_random_main(game),
         {:ok, euro_numbers} <- generate_half_random_euro(game) do
      result = %{main: Enum.sort(main_numbers), euro: Enum.sort(euro_numbers)}
      validate_half_random_result(result, game)
    end
  end

  # Generate main numbers for half random strategy
  defp generate_half_random_main(game) do
    %{count: count, min: min, max: max} = game.main

    # Randomly select half of the numbers (e.g. 25 out of 50)
    all_main = min..max |> Enum.to_list()
    selected_pool = Enum.take_random(all_main, game.vip.pool_main)

    # Select the per-game odd/even split (historically 3 odd + 2 even for
    # Eurojackpot), then fill to the full count
    main_numbers =
      select_preferred_parity(selected_pool,
        odd_count: half_random_odd_count(game),
        even_count: count - half_random_odd_count(game)
      )

    main_numbers = fill_to_count(main_numbers, selected_pool, count)

    # Ensure max 2 per decade and exactly `count` numbers
    final_numbers = enforce_decade_constraint(Enum.take_random(main_numbers, count), game)
    {:ok, final_numbers}
  end

  # Eurojackpot's half-random mode predates the game config and always used
  # 3 odd + 2 even (the inverse of the VIP split); other games use the VIP split
  defp half_random_odd_count(%{id: "eurojackpot"}), do: 3
  defp half_random_odd_count(game), do: game.vip.parity_odd

  # Generate euro numbers for half random strategy
  defp generate_half_random_euro(%{bonus: %{count: 0}}), do: {:ok, []}

  defp generate_half_random_euro(game) do
    %{count: count, min: min, max: max} = game.bonus

    # Randomly select half of the bonus numbers (e.g. 6 out of 12)
    all_euro = min..max |> Enum.to_list()
    selected_pool = Enum.take_random(all_euro, game.vip.pool_bonus)

    # Select 1 odd and 1 even, then fill to the full count
    euro_numbers = select_preferred_parity(selected_pool, odd_count: 1, even_count: 1)
    euro_numbers = fill_to_count(euro_numbers, selected_pool, count)

    {:ok, Enum.take(euro_numbers, count)}
  end

  # Select specified count of odd and even numbers from pool
  defp select_preferred_parity(pool, opts) do
    odd_count = Keyword.get(opts, :odd_count, 0)
    even_count = Keyword.get(opts, :even_count, 0)

    odd_numbers = pool |> Enum.filter(&(rem(&1, 2) == 1))
    even_numbers = pool |> Enum.filter(&(rem(&1, 2) == 0))

    selected_odd = Enum.take_random(odd_numbers, min(odd_count, length(odd_numbers)))
    selected_even = Enum.take_random(even_numbers, min(even_count, length(even_numbers)))

    selected_odd ++ selected_even
  end

  # Fill numbers list to target count from remaining pool
  defp fill_to_count(numbers, pool, target_count) do
    remaining_needed = target_count - length(numbers)

    if remaining_needed > 0 do
      remaining_pool = pool -- numbers
      additional = Enum.take_random(remaining_pool, remaining_needed)
      numbers ++ additional
    else
      numbers
    end
  end

  # Validate the final result
  defp validate_half_random_result(result, game) do
    main_count = game.main.count
    euro_count = game.bonus.count

    cond do
      length(result.main) != main_count ->
        {:error, :invalid_main_count}

      length(result.euro) != euro_count ->
        {:error, :invalid_euro_count}

      not Enum.all?(result.main, &(&1 in game.main.min..game.main.max)) ->
        {:error, :main_out_of_range}

      euro_count > 0 and not Enum.all?(result.euro, &(&1 in game.bonus.min..game.bonus.max)) ->
        {:error, :euro_out_of_range}

      length(Enum.uniq(result.main)) != main_count ->
        {:error, :main_duplicates}

      length(Enum.uniq(result.euro)) != euro_count ->
        {:error, :euro_duplicates}

      true ->
        {:ok, result}
    end
  end

  # Ensure max 2 numbers per decade (10s, 20s, 30s, ...)
  defp enforce_decade_constraint(numbers, game) do
    target_count = game.main.count

    # Group by decade
    by_decade = Enum.group_by(numbers, fn n -> div(n - 1, 10) end)

    # For each decade, keep max 2 numbers
    constrained =
      Enum.flat_map(by_decade, fn {_decade, nums} ->
        Enum.take_random(nums, min(2, length(nums)))
      end)

    # Ensure we have exactly `target_count` numbers
    case length(constrained) do
      ^target_count ->
        constrained

      count when count < target_count ->
        # Fill with numbers from decades that have space
        decades_with_space =
          0..last_decade(game)
          |> Enum.filter(fn decade ->
            existing = Map.get(by_decade, decade, [])
            length(existing) < 2
          end)

        available_numbers =
          decades_with_space
          |> Enum.flat_map(fn decade ->
            decade_start = decade * 10 + 1
            decade_end = min((decade + 1) * 10, game.main.max)
            decade_range = decade_start..decade_end |> Enum.to_list()
            decade_range -- constrained
          end)

        additional_needed = target_count - count
        additional = Enum.take_random(available_numbers, additional_needed)
        constrained ++ additional

      _count ->
        # Too many numbers, take a random subset
        Enum.take_random(constrained, target_count)
    end
  end

  defp last_decade(game), do: div(game.main.max - 1, 10)

  # ============================================================================
  # VIP1 Mode - Special simulation with reduced pool and strict constraints
  # ============================================================================

  @doc """
  Generates a VIP1 pool by randomly selecting ~50% of all numbers
  (pool sizes come from the game config; Eurojackpot: 25 main + 6 euro,
  Lotto: 25 main, no euro pool).

  ## Example

      iex> {:ok, pool} = generate_vip1_pool("eurojackpot")
      iex> length(pool.main_pool)
      25
      iex> length(pool.euro_pool)
      6

  """
  @spec generate_vip1_pool(String.t() | map()) ::
          {:ok, %{main_pool: [pos_integer()], euro_pool: [pos_integer()]}}
  def generate_vip1_pool(game \\ Games.default_id()) do
    game = Games.get!(game)

    all_main = game.main.min..game.main.max |> Enum.to_list()
    main_pool = Enum.take_random(all_main, game.vip.pool_main)

    euro_pool =
      if game.bonus.count > 0 do
        all_euro = game.bonus.min..game.bonus.max |> Enum.to_list()
        Enum.take_random(all_euro, game.vip.pool_bonus)
      else
        []
      end

    {:ok, %{main_pool: Enum.sort(main_pool), euro_pool: Enum.sort(euro_pool)}}
  end

  @doc """
  Validates that a VIP1 pool contains all target numbers needed for 1st prize.

  Returns `:ok` if all target numbers are in the pool, or `{:error, reason}` with details
  about which numbers are missing.

  ## Parameters

  - `pool` - The VIP1 pool with `:main_pool` and `:euro_pool` lists
  - `target_main` - List of 5 main target numbers
  - `target_euro` - List of 2 euro target numbers

  ## Example

      iex> pool = %{main_pool: [1,2,3,4,5,...], euro_pool: [1,2,3,4,5,6]}
      iex> validate_vip1_pool_contains_target(pool, [1,2,3,4,5], [1,2])
      :ok

      iex> validate_vip1_pool_contains_target(pool, [1,2,3,4,50], [1,11])
      {:error, %{missing_main: [50], missing_euro: [11]}}

  """
  @spec validate_vip1_pool_contains_target(map(), [pos_integer()], [pos_integer()]) ::
          :ok | {:error, map()}
  def validate_vip1_pool_contains_target(pool, target_main, target_euro) do
    main_set = MapSet.new(pool.main_pool)
    euro_set = MapSet.new(pool.euro_pool)

    missing_main = Enum.reject(target_main, &MapSet.member?(main_set, &1))
    missing_euro = Enum.reject(target_euro, &MapSet.member?(euro_set, &1))

    cond do
      missing_main != [] and missing_euro != [] ->
        {:error, %{missing_main: missing_main, missing_euro: missing_euro}}

      missing_main != [] ->
        {:error, %{missing_main: missing_main, missing_euro: []}}

      missing_euro != [] ->
        {:error, %{missing_main: [], missing_euro: missing_euro}}

      true ->
        :ok
    end
  end

  @doc """
  Generates numbers using VIP2 mode with dynamic blacklist applied to the strategy.

  VIP2 applies a runtime-generated blacklist to the strategy and generates numbers
  with VIP1-like constraints (max 2 per decade, 2 odd + 3 even).

  The blacklist is fixed for a whole simulation, so callers running many attempts
  should precompute the pools once with `prepare_vip2_pools/2` and pass them
  under the `:pools` key of the blacklist map.
  """
  @spec generate_vip2_numbers(Strategy.t(), map(), String.t() | map()) ::
          {:ok, %{main: [pos_integer()], euro: [pos_integer()], constraints_met: boolean()}}
  def generate_vip2_numbers(_strategy, blacklist, game \\ Games.default_id()) do
    game = Games.get!(game)
    pools = Map.get(blacklist, :pools) || prepare_vip2_pools(blacklist, game)

    # Apply VIP1 constraints to main numbers
    {:ok, main_numbers, constraints_met} =
      generate_vip1_main_from_split(pools.main_odd, pools.main_even, pools.main_available, game)

    # Generate euro numbers from available pool
    euro_numbers = Enum.take_random(pools.euro_available, game.bonus.count)

    {:ok,
     %{
       main: Enum.sort(main_numbers),
       euro: Enum.sort(euro_numbers),
       constraints_met: constraints_met
     }}
  end

  @doc """
  Precomputes available pools (with parity split) from a VIP2 blacklist.
  """
  @spec prepare_vip2_pools(%{main_blacklist: list(), euro_blacklist: list()}, String.t() | map()) ::
          map()
  def prepare_vip2_pools(blacklist, game \\ Games.default_id()) do
    game = Games.get!(game)
    main_available = Enum.reject(game.main.min..game.main.max, &(&1 in blacklist.main_blacklist))

    euro_available =
      if game.bonus.count > 0 do
        Enum.reject(game.bonus.min..game.bonus.max, &(&1 in blacklist.euro_blacklist))
      else
        []
      end

    %{
      main_available: main_available,
      main_odd: Enum.filter(main_available, &(rem(&1, 2) == 1)),
      main_even: Enum.filter(main_available, &(rem(&1, 2) == 0)),
      euro_available: euro_available
    }
  end

  @doc """
  Generates numbers using the VIP1 mode with the given pre-selected pool.

  VIP1 constraints:
  - Max 2 numbers per decade (1-10, 11-20, ...)
  - Exact per-game odd/even split (Eurojackpot: 2 odd + 3 even, Lotto: 3 + 3)
  - Euro numbers selected from the reduced pool (when the game has them)

  Returns `{:ok, result}` with `:main`, `:euro`, and `:constraints_met` fields,
  or `{:error, reason}` if constraints cannot be satisfied.

  ## Parameters

  - `pool` - The VIP1 pool with `:main_pool` and `:euro_pool` lists
  - `game` - Game id or config (default: Eurojackpot)

  """
  @spec generate_vip1_numbers(map(), String.t() | map()) ::
          {:ok, %{main: [pos_integer()], euro: [pos_integer()], constraints_met: boolean()}}
  def generate_vip1_numbers(pool, game \\ Games.default_id()) do
    game = Games.get!(game)

    {:ok, main_numbers, constraints_met} =
      generate_vip1_main_with_constraints(pool.main_pool, game)

    euro_numbers = Enum.take_random(pool.euro_pool, game.bonus.count)

    {:ok,
     %{
       main: Enum.sort(main_numbers),
       euro: Enum.sort(euro_numbers),
       constraints_met: constraints_met
     }}
  end

  # Generate main numbers with VIP1 constraints: per-game odd/even split, max 2 per decade
  defp generate_vip1_main_with_constraints(main_pool, game) do
    # Separate odd and even numbers
    odd_numbers = Enum.filter(main_pool, &(rem(&1, 2) == 1))
    even_numbers = Enum.filter(main_pool, &(rem(&1, 2) == 0))

    generate_vip1_main_from_split(odd_numbers, even_numbers, main_pool, game)
  end

  defp generate_vip1_main_from_split(odd_numbers, even_numbers, main_pool, game) do
    %{parity_odd: odd_target, parity_even: even_target} = game.vip
    count = game.main.count

    # Try to select the exact odd/even split
    selected_odd = Enum.take_random(odd_numbers, min(odd_target, length(odd_numbers)))
    selected_even = Enum.take_random(even_numbers, min(even_target, length(even_numbers)))

    initial_selection = selected_odd ++ selected_even

    # Check if we got the right parity ratio
    parity_ok = length(selected_odd) == odd_target and length(selected_even) == even_target

    # Fill to the full count if needed
    selection =
      if length(initial_selection) < count do
        remaining_pool = main_pool -- initial_selection
        additional = Enum.take_random(remaining_pool, count - length(initial_selection))
        initial_selection ++ additional
      else
        initial_selection
      end

    # Apply decade constraint
    final_selection = enforce_vip1_decade_constraint(selection, main_pool, game)

    # Check final constraints
    final_odd = Enum.count(final_selection, &(rem(&1, 2) == 1))
    final_even = Enum.count(final_selection, &(rem(&1, 2) == 0))
    decade_ok = check_decade_constraint(final_selection)

    constraints_met =
      parity_ok and final_odd == odd_target and final_even == even_target and decade_ok

    {:ok, final_selection, constraints_met}
  end

  # Enforce max 2 per decade for VIP1, using only numbers from the pool
  defp enforce_vip1_decade_constraint(numbers, pool, game) do
    count = game.main.count
    by_decade = Enum.group_by(numbers, fn n -> div(n - 1, 10) end)

    # First, keep max 2 per decade from selected
    constrained =
      Enum.flat_map(by_decade, fn {_decade, nums} ->
        Enum.take_random(nums, min(2, length(nums)))
      end)

    # If we need more numbers, fill from pool respecting decade limits
    if length(constrained) < count do
      fill_vip1_decade_constraint(constrained, pool, count)
    else
      Enum.take(constrained, count)
    end
  end

  defp fill_vip1_decade_constraint(current, pool, target) do
    if length(current) >= target do
      current
    else
      current_by_decade = Enum.group_by(current, fn n -> div(n - 1, 10) end)

      # Find available numbers from pool that fit decade constraints
      available =
        (pool -- current)
        |> Enum.filter(fn n ->
          decade = div(n - 1, 10)
          existing_in_decade = Map.get(current_by_decade, decade, [])
          length(existing_in_decade) < 2
        end)

      if available == [] do
        # Can't satisfy constraint, return what we have + random to fill
        remaining = (pool -- current) |> Enum.take_random(target - length(current))
        current ++ remaining
      else
        new_number = Enum.random(available)
        fill_vip1_decade_constraint([new_number | current], pool, target)
      end
    end
  end

  # Check if numbers satisfy decade constraint (max 2 per decade)
  defp check_decade_constraint(numbers) do
    numbers
    |> Enum.group_by(fn n -> div(n - 1, 10) end)
    |> Enum.all?(fn {_decade, nums} -> length(nums) <= 2 end)
  end

  @doc """
  Validates if target numbers meet VIP constraints (per-game odd/even split,
  max 2 per decade).

  Returns `:ok` if valid, or `{:error, reasons}` with list of violated constraints.
  """
  @spec validate_vip_constraints(list(), list(), String.t() | map()) :: :ok | {:error, list()}
  def validate_vip_constraints(target_main, _target_euro, game \\ Games.default_id()) do
    game = Games.get!(game)
    parity_errors = check_vip_parity_constraint(target_main, game)
    decade_errors = check_vip_decade_constraint(target_main, game)

    errors = parity_errors ++ decade_errors

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  defp check_vip_parity_constraint(target_main, game) do
    %{parity_odd: odd_target, parity_even: even_target} = game.vip
    odd_count = Enum.count(target_main, &(rem(&1, 2) == 1))
    even_count = Enum.count(target_main, &(rem(&1, 2) == 0))

    if odd_count != odd_target or even_count != even_target do
      [
        "Poszukiwane liczby główne muszą mieć #{odd_target} nieparzyste i #{even_target} parzyste (masz: #{odd_count} niep., #{even_count} parz.)"
      ]
    else
      []
    end
  end

  defp check_vip_decade_constraint(target_main, game) do
    by_decade = Enum.group_by(target_main, fn n -> div(n - 1, 10) end)

    violations =
      Enum.filter(by_decade, fn {_decade, nums} -> length(nums) > 2 end)
      |> Enum.map(fn {decade, nums} ->
        decade_range = format_decade_range(decade, game)
        "Dziesiątka #{decade_range}: #{length(nums)} liczb #{inspect(nums)}"
      end)

    if violations != [] do
      ["Maksymalnie 2 liczby w jednej dziesiątce. Przekroczenia: #{Enum.join(violations, ", ")}"]
    else
      []
    end
  end

  defp format_decade_range(decade, game) do
    "#{decade * 10 + 1}-#{min((decade + 1) * 10, game.main.max)}"
  end

  @doc """
  Validates if target numbers can be generated by a strategy based on its rules.

  Checks hard constraints like:
  - VIP constraints (for VIP strategies only): exactly 2 odd + 3 even, max 2 per decade
  - Blacklisted numbers (hard constraint for all strategies)
  - Only even/only odd requirements (hard constraint)

  Ratios like 3:2 or 2:3 are NOT enforced as hard constraints for non-VIP strategies
  because they're preferences, not absolute requirements.

  Returns `:ok` if valid, or `{:error, reasons}` with list of violated constraints.
  """
  @spec validate_strategy_constraints(Strategy.t(), list(), list(), String.t() | map()) ::
          :ok | {:error, list()}
  def validate_strategy_constraints(
        %Strategy{rules: rules, name: name},
        target_main,
        target_euro,
        game \\ Games.default_id()
      ) do
    # First check if this is a VIP strategy - apply VIP constraints
    vip_errors =
      if vip_strategy?(name) do
        case validate_vip_constraints(target_main, target_euro, game) do
          :ok -> []
          {:error, errors} -> errors
        end
      else
        []
      end

    # Check strategy-specific constraints (only hard constraints)
    main_errors = validate_main_constraints(rules.main_numbers, target_main)
    euro_errors = validate_euro_constraints(rules.euro_numbers, target_euro)

    all_errors = vip_errors ++ main_errors ++ euro_errors

    if all_errors == [] do
      :ok
    else
      {:error, all_errors}
    end
  end

  defp validate_main_constraints(rules, target_main) do
    # Only check hard constraints
    parity_errors = check_hard_parity_constraint(rules.ratio_even_odd, target_main, "głównych")
    blacklist_errors = check_blacklist_constraint(rules.blacklist, target_main, "głównych")

    parity_errors ++ blacklist_errors
  end

  defp validate_euro_constraints(rules, target_euro) do
    # Only check hard constraints
    parity_errors = check_hard_parity_constraint(rules.ratio_even_odd, target_euro, "euro")
    blacklist_errors = check_blacklist_constraint(rules.blacklist, target_euro, "euro")

    parity_errors ++ blacklist_errors
  end

  # Only check HARD parity constraints: when ratio is 0 for even or odd (e.g. [5, 0] = only even)
  defp check_hard_parity_constraint([required_even, required_odd], numbers, type) do
    actual_even = Enum.count(numbers, &(rem(&1, 2) == 0))
    actual_odd = Enum.count(numbers, &(rem(&1, 2) == 1))

    cond do
      # Hard constraint: strategy requires ONLY odd numbers (no even allowed)
      required_even == 0 and actual_even > 0 ->
        [
          "Strategia wymaga tylko nieparzystych liczb #{type}, ale losowanie ma #{actual_even} parzystych"
        ]

      # Hard constraint: strategy requires ONLY even numbers (no odd allowed)
      required_odd == 0 and actual_odd > 0 ->
        [
          "Strategia wymaga tylko parzystych liczb #{type}, ale losowanie ma #{actual_odd} nieparzystych"
        ]

      # For ratios like [3, 2] or [2, 3], these are preferences, NOT hard constraints
      # Only VIP strategies have strict parity requirements (checked separately)
      true ->
        []
    end
  end

  defp check_blacklist_constraint(blacklist, numbers, type) do
    blocked = Enum.filter(numbers, &(&1 in blacklist))

    if blocked != [] do
      [
        "Strategia ma na blackliście liczby #{type}: #{Enum.join(blocked, ", ")}, które są w losowaniu"
      ]
    else
      []
    end
  end

  defp vip_strategy?(name) do
    name_upper = String.upcase(name)
    String.contains?(name_upper, "VIP1") or String.contains?(name_upper, "VIP2")
  end

  @doc """
  Returns information about VIP1 mode constraints for display.
  """
  @spec vip1_constraints_info(String.t() | map()) :: map()
  def vip1_constraints_info(game \\ Games.default_id()) do
    game = Games.get!(game)

    %{
      pool_size: %{
        main: game.vip.pool_main,
        euro: game.vip.pool_bonus,
        main_total: game.main.max,
        euro_total: game.bonus.max
      },
      parity: %{odd: game.vip.parity_odd, even: game.vip.parity_even},
      decade_limit: 2,
      description:
        "VIP1: Losowo pomiń 50% liczb (#{game.vip.pool_main} głównych#{if game.bonus.count > 0, do: ", #{game.vip.pool_bonus} euro", else: ""}), " <>
          "następnie losuj #{game.vip.parity_odd} nieparzyste + #{game.vip.parity_even} parzyste, max 2 w dziesiątce"
    }
  end

  @doc """
  Returns strategy pool details showing which numbers are in hot/cold/random pools.

  When half_random_mode is true, returns reduced pools (~half of each range).

  Returns a map with `:main_numbers` and `:euro_numbers` pools.
  """
  @spec get_strategy_pools(Strategy.t(), keyword()) :: %{
          main_numbers: %{hot: [integer()], cold: [integer()], random: [integer()]},
          euro_numbers: %{hot: [integer()], random: [integer()]}
        }
  def get_strategy_pools(%Strategy{rules: rules}, opts \\ []) do
    game = Games.get!(Keyword.get(opts, :game, Games.default_id()))
    half_random_mode = Keyword.get(opts, :half_random_mode, false)

    if half_random_mode do
      get_half_random_strategy_pools(rules, game)
    else
      %{
        main_numbers: build_main_pools(rules.main_numbers, game),
        euro_numbers: build_euro_pools(rules.euro_numbers, game)
      }
    end
  end

  # Get pools for half_random mode - reduced pools
  defp get_half_random_strategy_pools(rules, game) do
    # Main numbers: randomly select about half of the range
    all_main = game.main.min..game.main.max |> Enum.to_list()
    selected_main_pool = Enum.take_random(all_main, game.vip.pool_main)

    # Euro numbers: randomly select about half of the range (when present)
    selected_euro_pool =
      if game.bonus.count > 0 do
        all_euro = game.bonus.min..game.bonus.max |> Enum.to_list()
        Enum.take_random(all_euro, game.vip.pool_bonus)
      else
        []
      end

    # Build pools from the reduced sets
    main_pools = build_main_pools_from_reduced(rules.main_numbers, selected_main_pool)
    euro_pools = build_euro_pools_from_reduced(rules.euro_numbers, selected_euro_pool)

    %{
      main_numbers: main_pools,
      euro_numbers: euro_pools
    }
  end

  # Build pools from reduced main numbers set
  defp build_main_pools_from_reduced(main_rules, reduced_pool) do
    all_numbers = MapSet.new(reduced_pool)
    hot_set = MapSet.new(main_rules.preferred_hot || []) |> MapSet.intersection(all_numbers)
    cold_set = MapSet.new(main_rules.preferred_cold || []) |> MapSet.intersection(all_numbers)
    random_set = MapSet.difference(all_numbers, MapSet.union(hot_set, cold_set))

    %{
      hot: MapSet.to_list(hot_set),
      cold: MapSet.to_list(cold_set),
      random: MapSet.to_list(random_set)
    }
  end

  # Build pools from reduced euro numbers set
  defp build_euro_pools_from_reduced(euro_rules, reduced_pool) do
    all_numbers = MapSet.new(reduced_pool)
    hot_set = MapSet.new(euro_rules.preferred || []) |> MapSet.intersection(all_numbers)
    random_set = MapSet.difference(all_numbers, hot_set)

    %{
      hot: MapSet.to_list(hot_set),
      random: MapSet.to_list(random_set)
    }
  end

  ## Main Numbers (count and range per game)

  defp generate_main_numbers(main_rules, precomputed_pools, game) do
    pools = precomputed_pools || build_main_pools(main_rules, game)
    [even_count, odd_count] = main_rules.ratio_even_odd
    [low_count, high_count] = main_rules.ratio_low_high
    weights_map = weights_to_map(main_rules.weights, [:hot, :cold, :random])

    generate_with_constraints(pools, weights_map, game.main.count, %{
      even: even_count,
      odd: odd_count,
      low: low_count,
      high: high_count,
      low_max: game.main.low_max,
      count: game.main.count,
      range: game.main.min..game.main.max
    })
  end

  defp build_main_pools(main_rules, game) do
    all_numbers = MapSet.new(game.main.min..game.main.max)
    blacklist_set = MapSet.new(main_rules.blacklist || [])

    available_numbers =
      all_numbers
      |> MapSet.difference(blacklist_set)
      |> apply_hard_exclusions(main_rules, game)

    hot_set = MapSet.new(main_rules.preferred_hot || []) |> MapSet.intersection(available_numbers)

    cold_set =
      MapSet.new(main_rules.preferred_cold || []) |> MapSet.intersection(available_numbers)

    random_set = MapSet.difference(available_numbers, MapSet.union(hot_set, cold_set))

    %{
      hot: MapSet.to_list(hot_set),
      cold: MapSet.to_list(cold_set),
      random: MapSet.to_list(random_set)
    }
  end

  # In minimum-ratio mode (rules cover fewer numbers than the game's main
  # count, e.g. Eurojackpot-shaped rules used for Lotto) the extra numbers are
  # unconstrained, so a 0-target ratio ("only odd", "only low") must be
  # enforced structurally by removing the excluded numbers from the pool.
  defp apply_hard_exclusions(available_numbers, main_rules, game) do
    [even_target, odd_target] = main_rules.ratio_even_odd
    [low_target, high_target] = main_rules.ratio_low_high

    if even_target + odd_target == game.main.count do
      available_numbers
    else
      low_max = game.main.low_max

      available_numbers
      |> reject_when(even_target == 0, &(rem(&1, 2) == 0))
      |> reject_when(odd_target == 0, &(rem(&1, 2) == 1))
      |> reject_when(low_target == 0, &(&1 <= low_max))
      |> reject_when(high_target == 0, &(&1 > low_max))
    end
  end

  defp reject_when(set, false, _fun), do: set
  defp reject_when(set, true, fun), do: set |> Enum.reject(fun) |> MapSet.new()

  defp generate_with_constraints(pools, weights, count, constraints) do
    do_generate_with_constraints(pools, weights, [], count, constraints, 0)
  end

  defp do_generate_with_constraints(_pools, _weights, selected, 0, _constraints, _attempts) do
    selected
  end

  defp do_generate_with_constraints(
         _pools,
         _weights,
         _selected,
         _remaining,
         constraints,
         attempts
       )
       when attempts > 1000 do
    # If we can't satisfy constraints after many attempts, try to generate
    # numbers that at least respect the ranges, even if ratios aren't perfect
    # This is better than completely random fallback
    generate_fallback_numbers(constraints)
  end

  defp do_generate_with_constraints(pools, weights, selected, remaining, constraints, attempts) do
    pool_name = weighted_random_pool(weights)
    available = pools[pool_name]

    candidates =
      available
      |> Enum.reject(&(&1 in selected))
      |> filter_by_constraints(selected, remaining, constraints)

    if Enum.empty?(candidates) do
      # Retry with different pool
      do_generate_with_constraints(pools, weights, selected, remaining, constraints, attempts + 1)
    else
      number = Enum.random(candidates)

      do_generate_with_constraints(
        pools,
        weights,
        [number | selected],
        remaining - 1,
        update_constraints(constraints, number),
        0
      )
    end
  end

  defp generate_fallback_numbers(constraints) do
    # Try to satisfy constraints as much as possible
    even_needed = constraints.even
    odd_needed = constraints.odd
    low_needed = constraints.low
    high_needed = constraints.high
    range = constraints.range
    low_max = constraints.low_max
    count = constraints.count

    result = []
    result = add_numbers_by_constraint(result, even_needed, &(rem(&1, 2) == 0), range)
    result = add_numbers_by_constraint(result, odd_needed, &(rem(&1, 2) == 1), range)
    result = add_numbers_by_constraint(result, low_needed, &(&1 <= low_max), range)
    result = add_numbers_by_constraint(result, high_needed, &(&1 > low_max), range)

    # Fill remaining slots with random numbers
    remaining = count - length(result)

    if remaining > 0 do
      available = range |> Enum.reject(&(&1 in result))
      result ++ Enum.take_random(available, remaining)
    else
      Enum.take(result, count)
    end
  end

  defp add_numbers_by_constraint(result, needed, constraint_fn, range) do
    if needed > 0 do
      available = range |> Enum.reject(&(&1 in result)) |> Enum.filter(constraint_fn)

      if Enum.empty?(available) do
        result
      else
        result ++ [Enum.random(available)]
      end
    else
      result
    end
  end

  defp filter_by_constraints(candidates, selected, remaining, constraints) do
    Enum.filter(candidates, fn num ->
      satisfies_current_constraints(num, constraints) &&
        can_satisfy_remaining_constraints(num, selected, remaining, constraints)
    end)
  end

  defp satisfies_current_constraints(num, constraints) do
    satisfies_even_odd(num, constraints) && satisfies_low_high(num, constraints)
  end

  defp satisfies_even_odd(num, constraints) do
    even_satisfies = constraints.even > 0 && rem(num, 2) == 0
    odd_satisfies = constraints.odd > 0 && rem(num, 2) == 1
    no_even_odd_constraint = constraints.even == 0 && constraints.odd == 0

    even_satisfies || odd_satisfies || no_even_odd_constraint
  end

  defp satisfies_low_high(num, constraints) do
    low_satisfies = constraints.low > 0 && num <= constraints.low_max
    high_satisfies = constraints.high > 0 && num > constraints.low_max
    no_low_high_constraint = constraints.low == 0 && constraints.high == 0

    low_satisfies || high_satisfies || no_low_high_constraint
  end

  defp can_satisfy_remaining_constraints(num, _selected, remaining, constraints) do
    # Calculate what constraints would be after selecting this number
    updated_constraints = update_constraints(constraints, num)
    remaining_count = remaining - 1

    # Check if we have enough numbers available to satisfy remaining constraints
    even_needed = updated_constraints.even
    odd_needed = updated_constraints.odd
    low_needed = updated_constraints.low
    high_needed = updated_constraints.high

    # We need at least as many numbers remaining as the sum of needed constraints
    # (with some flexibility since a number can satisfy multiple constraints)
    total_needed = max(even_needed + odd_needed, low_needed + high_needed)
    remaining_count >= total_needed
  end

  defp update_constraints(constraints, number) do
    constraints
    |> update_if_even_odd(number)
    |> update_if_low_high(number)
  end

  defp update_if_even_odd(constraints, number) do
    if rem(number, 2) == 0 do
      %{constraints | even: max(0, constraints.even - 1)}
    else
      %{constraints | odd: max(0, constraints.odd - 1)}
    end
  end

  defp update_if_low_high(constraints, number) do
    if number <= constraints.low_max do
      %{constraints | low: max(0, constraints.low - 1)}
    else
      %{constraints | high: max(0, constraints.high - 1)}
    end
  end

  defp weights_to_map(weights_struct, fields) when is_struct(weights_struct) do
    Enum.into(fields, %{}, fn field -> {field, Map.get(weights_struct, field)} end)
  end

  defp weights_to_map(weights_map, _fields) when is_map(weights_map) do
    weights_map
  end

  defp weights_to_map(nil, _fields) do
    raise ArgumentError, "weights cannot be nil"
  end

  defp weighted_random_pool(weights) do
    rand = :rand.uniform()

    weights
    |> Map.to_list()
    |> Enum.reduce_while(0, fn {pool, weight}, acc ->
      new_acc = acc + weight
      if rand <= new_acc, do: {:halt, pool}, else: {:cont, new_acc}
    end)
  end

  ## Euro Numbers (count and range per game; games without bonus numbers return [])

  defp generate_euro_numbers(_euro_rules, _precomputed_pools, %{bonus: %{count: 0}}), do: []

  defp generate_euro_numbers(euro_rules, precomputed_pools, game) do
    pools = precomputed_pools || build_euro_pools(euro_rules, game)
    [even_count, odd_count] = euro_rules.ratio_even_odd
    weights_map = weights_to_map(euro_rules.weights, [:hot, :random])

    generate_euro_with_constraints(pools, weights_map, game.bonus.count, %{
      even: even_count,
      odd: odd_count,
      count: game.bonus.count,
      range: game.bonus.min..game.bonus.max
    })
  end

  defp build_euro_pools(_euro_rules, %{bonus: %{count: 0}}), do: %{hot: [], random: []}

  defp build_euro_pools(euro_rules, game) do
    all_numbers = MapSet.new(game.bonus.min..game.bonus.max)
    blacklist_set = MapSet.new(euro_rules.blacklist || [])
    available_numbers = MapSet.difference(all_numbers, blacklist_set)

    hot_set = MapSet.new(euro_rules.preferred || []) |> MapSet.intersection(available_numbers)
    random_set = MapSet.difference(available_numbers, hot_set)

    %{
      hot: MapSet.to_list(hot_set),
      random: MapSet.to_list(random_set)
    }
  end

  defp generate_euro_with_constraints(pools, weights, count, constraints) do
    do_generate_euro_with_constraints(pools, weights, [], count, constraints, 0)
  end

  defp do_generate_euro_with_constraints(_pools, _weights, selected, 0, _constraints, _attempts) do
    selected
  end

  defp do_generate_euro_with_constraints(
         _pools,
         _weights,
         _selected,
         _remaining,
         constraints,
         attempts
       )
       when attempts > 1000 do
    # Fallback: try to satisfy even/odd constraints as much as possible
    generate_euro_fallback_numbers(constraints)
  end

  defp do_generate_euro_with_constraints(
         pools,
         weights,
         selected,
         remaining,
         constraints,
         attempts
       ) do
    pool_name = weighted_random_pool(weights)
    available = pools[pool_name]

    candidates =
      available
      |> Enum.reject(&(&1 in selected))
      |> filter_euro_by_constraints(selected, remaining, constraints)

    if Enum.empty?(candidates) do
      # Retry with different pool
      do_generate_euro_with_constraints(
        pools,
        weights,
        selected,
        remaining,
        constraints,
        attempts + 1
      )
    else
      number = Enum.random(candidates)
      updated_constraints = update_euro_constraints(constraints, number)

      do_generate_euro_with_constraints(
        pools,
        weights,
        [number | selected],
        remaining - 1,
        updated_constraints,
        0
      )
    end
  end

  defp generate_euro_fallback_numbers(constraints) do
    even_needed = constraints.even
    odd_needed = constraints.odd
    range = constraints.range
    count = constraints.count

    result = []
    result = add_numbers_by_constraint(result, even_needed, &(rem(&1, 2) == 0), range)
    result = add_numbers_by_constraint(result, odd_needed, &(rem(&1, 2) == 1), range)

    # Fill remaining slots
    remaining = count - length(result)

    if remaining > 0 do
      available = range |> Enum.reject(&(&1 in result))
      result ++ Enum.take_random(available, remaining)
    else
      Enum.take(result, count)
    end
  end

  defp filter_euro_by_constraints(candidates, _selected, remaining, constraints) do
    Enum.filter(candidates, fn num ->
      even_ok? = constraints.even == 0 || rem(num, 2) == 0
      odd_ok? = constraints.odd == 0 || rem(num, 2) == 1

      # Check if we can satisfy remaining constraints
      can_satisfy = even_ok? || odd_ok?
      can_satisfy && can_satisfy_euro_remaining(num, remaining, constraints)
    end)
  end

  defp can_satisfy_euro_remaining(num, remaining, constraints) do
    updated_constraints = update_euro_constraints(constraints, num)
    remaining_count = remaining - 1
    even_needed = updated_constraints.even
    odd_needed = updated_constraints.odd
    total_needed = even_needed + odd_needed
    remaining_count >= total_needed
  end

  defp update_euro_constraints(constraints, number) do
    if rem(number, 2) == 0 do
      %{constraints | even: max(0, constraints.even - 1)}
    else
      %{constraints | odd: max(0, constraints.odd - 1)}
    end
  end

  ## Validation

  defp validate_result(%{main: main, euro: euro}, rules, game) do
    with :ok <- validate_main_numbers(main, rules.main_numbers, game),
         :ok <- validate_euro_numbers(euro, rules.euro_numbers, game) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_main_numbers(numbers, main_rules, game) do
    count = game.main.count

    cond do
      length(numbers) != count ->
        {:error, :invalid_count}

      not Enum.all?(numbers, &(&1 in game.main.min..game.main.max)) ->
        {:error, :out_of_range}

      length(Enum.uniq(numbers)) != count ->
        {:error, :duplicates}

      not validate_ratios(numbers, main_rules, game) ->
        {:error, :constraints_not_satisfied}

      true ->
        :ok
    end
  end

  defp validate_euro_numbers(numbers, _euro_rules, %{bonus: %{count: 0}}) do
    if numbers == [], do: :ok, else: {:error, :invalid_count}
  end

  defp validate_euro_numbers(numbers, euro_rules, game) do
    count = game.bonus.count

    cond do
      length(numbers) != count ->
        {:error, :invalid_count}

      not Enum.all?(numbers, &(&1 in game.bonus.min..game.bonus.max)) ->
        {:error, :out_of_range}

      length(Enum.uniq(numbers)) != count ->
        {:error, :duplicates}

      not validate_euro_ratios(numbers, euro_rules) ->
        {:error, :constraints_not_satisfied}

      true ->
        :ok
    end
  end

  # Strategy ratios are Eurojackpot-shaped (sum to 5). When they cover the
  # game's full main count they are exact targets; otherwise (Lotto: 6 numbers)
  # they act as minimum counts and the extra numbers are unconstrained.
  defp validate_ratios(numbers, main_rules, game) do
    [even_target, odd_target] = main_rules.ratio_even_odd
    [low_target, high_target] = main_rules.ratio_low_high
    exact? = even_target + odd_target == game.main.count

    even_count = Enum.count(numbers, &(rem(&1, 2) == 0))
    odd_count = Enum.count(numbers, &(rem(&1, 2) == 1))
    low_count = Enum.count(numbers, &(&1 <= game.main.low_max))
    high_count = Enum.count(numbers, &(&1 > game.main.low_max))

    if exact? do
      even_count == even_target &&
        odd_count == odd_target &&
        low_count == low_target &&
        high_count == high_target
    else
      minimum_ok?(even_count, even_target) &&
        minimum_ok?(odd_count, odd_target) &&
        minimum_ok?(low_count, low_target) &&
        minimum_ok?(high_count, high_target)
    end
  end

  # A 0-target in minimum mode is a hard exclusion ("only odd" etc.),
  # matching the pool filtering in apply_hard_exclusions/3
  defp minimum_ok?(count, 0), do: count == 0
  defp minimum_ok?(count, target), do: count >= target

  defp validate_euro_ratios(numbers, euro_rules) do
    [even_target, odd_target] = euro_rules.ratio_even_odd

    even_count = Enum.count(numbers, &(rem(&1, 2) == 0))
    odd_count = Enum.count(numbers, &(rem(&1, 2) == 1))

    even_count == even_target && odd_count == odd_target
  end
end
