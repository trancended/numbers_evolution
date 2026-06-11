defmodule NumbersEvolution.Strategies.Generator do
  @moduledoc """
  Generates Eurojackpot number combinations based on strategy rules.

  The generator applies strategy rules including:
  - Even/odd ratios
  - Low/high ratios (for main numbers)
  - Preferred hot/cold numbers
  - Weighted pool selection (hot/cold/random)

  ## VIP1 Mode

  VIP1 mode is a special simulation type that:
  1. Randomly skips 50% of numbers (25 main from 50, 6 euro from 12) before starting
  2. Validates that the reduced pool can produce the target 1st prize numbers
  3. Applies additional constraints: max 2 numbers per decade, 2 odd + 3 even
  4. Saves the initial pool with the simulation for reproducibility
  """

  alias NumbersEvolution.Strategies.Strategy

  @doc """
  Generates a combination of numbers according to strategy rules.

  Returns a map with `:main` (5 numbers from 1-50) and `:euro` (2 numbers from 1-12).

  Validates that:
  - Main numbers are exactly 5 unique numbers in range 1-50
  - Euro numbers are exactly 2 unique numbers in range 1-12
  - All constraints (even/odd, low/high ratios) are satisfied
  """
  @spec generate_numbers(Strategy.t(), keyword()) ::
          {:ok, %{main: [pos_integer()], euro: [pos_integer()]}}
          | {:error, atom()}
  def generate_numbers(%Strategy{name: name} = strategy, opts \\ []) do
    half_random_mode = Keyword.get(opts, :half_random_mode, false)
    vip1_mode = Keyword.get(opts, :vip1_mode, false)
    vip1_pool = Keyword.get(opts, :vip1_pool, nil)
    vip2_blacklist = Keyword.get(opts, :vip2_blacklist, nil)
    pools = Keyword.get(opts, :pools, nil)

    cond do
      vip1_mode and vip1_pool != nil ->
        generate_vip1_numbers(vip1_pool)

      vip2_blacklist != nil ->
        generate_vip2_numbers(strategy, vip2_blacklist)

      String.contains?(name, "Losowo pomin połowę") or half_random_mode ->
        generate_half_random_strategy(strategy)

      true ->
        generate_numbers_standard(strategy, pools)
    end
  end

  @doc """
  Precomputes hot/cold/random pools for the standard generation path.

  Pools depend only on strategy rules, so simulations can build them once
  and pass them via `opts[:pools]` to `generate_numbers/2` instead of
  rebuilding MapSets on every attempt.
  """
  @spec build_pools(Strategy.t()) :: %{main: map(), euro: map()}
  def build_pools(%Strategy{rules: rules}) do
    %{
      main: build_main_pools(rules.main_numbers),
      euro: build_euro_pools(rules.euro_numbers)
    }
  end

  defp generate_numbers_standard(%Strategy{rules: rules}, pools) do
    main_numbers = generate_main_numbers(rules.main_numbers, pools[:main])
    euro_numbers = generate_euro_numbers(rules.euro_numbers, pools[:euro])

    result = %{main: Enum.sort(main_numbers), euro: Enum.sort(euro_numbers)}

    case validate_result(result, rules) do
      :ok -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  # Special strategy: randomly omit half numbers, then select 3 odd + 2 even with max 2 per decade
  defp generate_half_random_strategy(_strategy) do
    with {:ok, main_numbers} <- generate_half_random_main(),
         {:ok, euro_numbers} <- generate_half_random_euro() do
      result = %{main: Enum.sort(main_numbers), euro: Enum.sort(euro_numbers)}
      validate_half_random_result(result)
    end
  end

  # Generate main numbers for half random strategy
  defp generate_half_random_main do
    # Randomly select 25 out of 50
    all_main = 1..50 |> Enum.to_list()
    selected_pool = Enum.take_random(all_main, 25)

    # Select 3 odd and 2 even, then fill to 5 numbers
    main_numbers = select_preferred_parity(selected_pool, odd_count: 3, even_count: 2)
    main_numbers = fill_to_count(main_numbers, selected_pool, 5)

    # Ensure max 2 per decade and exactly 5 numbers
    final_numbers = enforce_decade_constraint(Enum.take_random(main_numbers, 5))
    {:ok, final_numbers}
  end

  # Generate euro numbers for half random strategy
  defp generate_half_random_euro do
    # Randomly select 6 out of 12
    all_euro = 1..12 |> Enum.to_list()
    selected_pool = Enum.take_random(all_euro, 6)

    # Select 1 odd and 1 even, then fill to 2 numbers
    euro_numbers = select_preferred_parity(selected_pool, odd_count: 1, even_count: 1)
    euro_numbers = fill_to_count(euro_numbers, selected_pool, 2)

    {:ok, Enum.take(euro_numbers, 2)}
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
  defp validate_half_random_result(result) do
    cond do
      length(result.main) != 5 -> {:error, :invalid_main_count}
      length(result.euro) != 2 -> {:error, :invalid_euro_count}
      not Enum.all?(result.main, &(&1 in 1..50)) -> {:error, :main_out_of_range}
      not Enum.all?(result.euro, &(&1 in 1..12)) -> {:error, :euro_out_of_range}
      length(Enum.uniq(result.main)) != 5 -> {:error, :main_duplicates}
      length(Enum.uniq(result.euro)) != 2 -> {:error, :euro_duplicates}
      true -> {:ok, result}
    end
  end

  # Ensure max 2 numbers per decade (10s, 20s, 30s, 40s, 50s)
  defp enforce_decade_constraint(numbers) do
    # Group by decade
    by_decade = Enum.group_by(numbers, fn n -> div(n - 1, 10) end)

    # For each decade, keep max 2 numbers
    constrained =
      Enum.flat_map(by_decade, fn {_decade, nums} ->
        Enum.take_random(nums, min(2, length(nums)))
      end)

    # Ensure we have exactly 5 numbers
    case length(constrained) do
      5 ->
        constrained

      count when count < 5 ->
        # Fill with numbers from decades that have space
        decades_with_space =
          0..4
          |> Enum.filter(fn decade ->
            existing = Map.get(by_decade, decade, [])
            length(existing) < 2
          end)

        available_numbers =
          decades_with_space
          |> Enum.flat_map(fn decade ->
            decade_start = decade * 10 + 1
            decade_end = min((decade + 1) * 10, 50)
            decade_range = decade_start..decade_end |> Enum.to_list()
            decade_range -- constrained
          end)

        additional_needed = 5 - count
        additional = Enum.take_random(available_numbers, additional_needed)
        constrained ++ additional

      _count ->
        # Too many numbers, take random 5
        Enum.take_random(constrained, 5)
    end
  end

  # ============================================================================
  # VIP1 Mode - Special simulation with reduced pool and strict constraints
  # ============================================================================

  @doc """
  Generates a VIP1 pool by randomly selecting 50% of all numbers.

  Returns a map with:
  - `:main_pool` - 25 randomly selected numbers from 1-50
  - `:euro_pool` - 6 randomly selected numbers from 1-12

  ## Example

      iex> {:ok, pool} = generate_vip1_pool()
      iex> length(pool.main_pool)
      25
      iex> length(pool.euro_pool)
      6

  """
  @spec generate_vip1_pool() :: {:ok, %{main_pool: [pos_integer()], euro_pool: [pos_integer()]}}
  def generate_vip1_pool do
    all_main = 1..50 |> Enum.to_list()
    all_euro = 1..12 |> Enum.to_list()

    main_pool = Enum.take_random(all_main, 25)
    euro_pool = Enum.take_random(all_euro, 6)

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
  should precompute the pools once with `prepare_vip2_pools/1` and pass them
  under the `:pools` key of the blacklist map.
  """
  @spec generate_vip2_numbers(Strategy.t(), map()) ::
          {:ok, %{main: [pos_integer()], euro: [pos_integer()], constraints_met: boolean()}}
  def generate_vip2_numbers(_strategy, blacklist) do
    pools = Map.get(blacklist, :pools) || prepare_vip2_pools(blacklist)

    # Apply VIP1 constraints to main numbers
    {:ok, main_numbers, constraints_met} =
      generate_vip1_main_from_split(pools.main_odd, pools.main_even, pools.main_available)

    # Generate euro numbers from available pool
    euro_numbers = Enum.take_random(pools.euro_available, 2)

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
  @spec prepare_vip2_pools(%{main_blacklist: list(), euro_blacklist: list()}) :: map()
  def prepare_vip2_pools(blacklist) do
    main_available = Enum.reject(1..50, &(&1 in blacklist.main_blacklist))
    euro_available = Enum.reject(1..12, &(&1 in blacklist.euro_blacklist))

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
  - Max 2 numbers per decade (0-9, 10-19, 20-29, 30-39, 40-50)
  - Exactly 2 odd + 3 even main numbers
  - Euro numbers selected from the reduced pool

  Returns `{:ok, result}` with `:main`, `:euro`, and `:constraints_met` fields,
  or `{:error, reason}` if constraints cannot be satisfied.

  ## Parameters

  - `pool` - The VIP1 pool with `:main_pool` and `:euro_pool` lists

  """
  @spec generate_vip1_numbers(map()) ::
          {:ok, %{main: [pos_integer()], euro: [pos_integer()], constraints_met: boolean()}}
  def generate_vip1_numbers(pool) do
    {:ok, main_numbers, constraints_met} = generate_vip1_main_with_constraints(pool.main_pool)
    euro_numbers = Enum.take_random(pool.euro_pool, 2)

    {:ok,
     %{
       main: Enum.sort(main_numbers),
       euro: Enum.sort(euro_numbers),
       constraints_met: constraints_met
     }}
  end

  # Generate main numbers with VIP1 constraints: 2 odd + 3 even, max 2 per decade
  defp generate_vip1_main_with_constraints(main_pool) do
    # Separate odd and even numbers
    odd_numbers = Enum.filter(main_pool, &(rem(&1, 2) == 1))
    even_numbers = Enum.filter(main_pool, &(rem(&1, 2) == 0))

    generate_vip1_main_from_split(odd_numbers, even_numbers, main_pool)
  end

  defp generate_vip1_main_from_split(odd_numbers, even_numbers, main_pool) do
    # Try to select exactly 2 odd and 3 even
    selected_odd = Enum.take_random(odd_numbers, min(2, length(odd_numbers)))
    selected_even = Enum.take_random(even_numbers, min(3, length(even_numbers)))

    initial_selection = selected_odd ++ selected_even

    # Check if we got the right parity ratio
    parity_ok = length(selected_odd) == 2 and length(selected_even) == 3

    # Fill to 5 if needed
    selection =
      if length(initial_selection) < 5 do
        remaining_pool = main_pool -- initial_selection
        additional = Enum.take_random(remaining_pool, 5 - length(initial_selection))
        initial_selection ++ additional
      else
        initial_selection
      end

    # Apply decade constraint
    final_selection = enforce_vip1_decade_constraint(selection, main_pool)

    # Check final constraints
    final_odd = Enum.count(final_selection, &(rem(&1, 2) == 1))
    final_even = Enum.count(final_selection, &(rem(&1, 2) == 0))
    decade_ok = check_decade_constraint(final_selection)
    constraints_met = parity_ok and final_odd == 2 and final_even == 3 and decade_ok

    {:ok, final_selection, constraints_met}
  end

  # Enforce max 2 per decade for VIP1, using only numbers from the pool
  defp enforce_vip1_decade_constraint(numbers, pool) do
    by_decade = Enum.group_by(numbers, fn n -> div(n - 1, 10) end)

    # First, keep max 2 per decade from selected
    constrained =
      Enum.flat_map(by_decade, fn {_decade, nums} ->
        Enum.take_random(nums, min(2, length(nums)))
      end)

    # If we need more numbers, fill from pool respecting decade limits
    if length(constrained) < 5 do
      fill_vip1_decade_constraint(constrained, pool, 5)
    else
      Enum.take(constrained, 5)
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
  Validates if target numbers meet VIP constraints (2 odd + 3 even, max 2 per decade).

  Returns `:ok` if valid, or `{:error, reasons}` with list of violated constraints.
  """
  @spec validate_vip_constraints(list(), list()) :: :ok | {:error, list()}
  def validate_vip_constraints(target_main, _target_euro) do
    parity_errors = check_vip_parity_constraint(target_main)
    decade_errors = check_vip_decade_constraint(target_main)

    errors = parity_errors ++ decade_errors

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  defp check_vip_parity_constraint(target_main) do
    odd_count = Enum.count(target_main, &(rem(&1, 2) == 1))
    even_count = Enum.count(target_main, &(rem(&1, 2) == 0))

    if odd_count != 2 or even_count != 3 do
      [
        "Poszukiwane liczby główne muszą mieć 2 nieparzyste i 3 parzyste (masz: #{odd_count} niep., #{even_count} parz.)"
      ]
    else
      []
    end
  end

  defp check_vip_decade_constraint(target_main) do
    by_decade = Enum.group_by(target_main, fn n -> div(n - 1, 10) end)

    violations =
      Enum.filter(by_decade, fn {_decade, nums} -> length(nums) > 2 end)
      |> Enum.map(fn {decade, nums} ->
        decade_range = format_decade_range(decade)
        "Dziesiątka #{decade_range}: #{length(nums)} liczb #{inspect(nums)}"
      end)

    if violations != [] do
      ["Maksymalnie 2 liczby w jednej dziesiątce. Przekroczenia: #{Enum.join(violations, ", ")}"]
    else
      []
    end
  end

  defp format_decade_range(0), do: "1-10"
  defp format_decade_range(1), do: "11-20"
  defp format_decade_range(2), do: "21-30"
  defp format_decade_range(3), do: "31-40"
  defp format_decade_range(4), do: "41-50"

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
  @spec validate_strategy_constraints(Strategy.t(), list(), list()) ::
          :ok | {:error, list()}
  def validate_strategy_constraints(%Strategy{rules: rules, name: name}, target_main, target_euro) do
    # First check if this is a VIP strategy - apply VIP constraints
    vip_errors =
      if vip_strategy?(name) do
        case validate_vip_constraints(target_main, target_euro) do
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
  @spec vip1_constraints_info() :: map()
  def vip1_constraints_info do
    %{
      pool_size: %{main: 25, euro: 6, main_total: 50, euro_total: 12},
      parity: %{odd: 2, even: 3},
      decade_limit: 2,
      description:
        "VIP1: Losowo pomiń 50% liczb (25 głównych, 6 euro), następnie losuj 2 nieparzyste + 3 parzyste, max 2 w dziesiątce"
    }
  end

  @doc """
  Returns strategy pool details showing which numbers are in hot/cold/random pools.

  When half_random_mode is true, returns reduced pools (25 main numbers, 6 euro numbers).

  Returns a map with `:main_numbers` and `:euro_numbers` pools.
  """
  @spec get_strategy_pools(Strategy.t(), keyword()) :: %{
          main_numbers: %{hot: [integer()], cold: [integer()], random: [integer()]},
          euro_numbers: %{hot: [integer()], random: [integer()]}
        }
  def get_strategy_pools(%Strategy{rules: rules}, opts \\ []) do
    half_random_mode = Keyword.get(opts, :half_random_mode, false)

    if half_random_mode do
      get_half_random_strategy_pools(rules)
    else
      %{
        main_numbers: build_main_pools(rules.main_numbers),
        euro_numbers: build_euro_pools(rules.euro_numbers)
      }
    end
  end

  # Get pools for half_random mode - reduced pools
  defp get_half_random_strategy_pools(rules) do
    # Main numbers: randomly select 25 out of 50
    all_main = 1..50 |> Enum.to_list()
    selected_main_pool = Enum.take_random(all_main, 25)

    # Euro numbers: randomly select 6 out of 12
    all_euro = 1..12 |> Enum.to_list()
    selected_euro_pool = Enum.take_random(all_euro, 6)

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

  ## Main Numbers (5 from 1-50)

  defp generate_main_numbers(main_rules, precomputed_pools) do
    pools = precomputed_pools || build_main_pools(main_rules)
    [even_count, odd_count] = main_rules.ratio_even_odd
    [low_count, high_count] = main_rules.ratio_low_high
    weights_map = weights_to_map(main_rules.weights, [:hot, :cold, :random])

    generate_with_constraints(pools, weights_map, 5, %{
      even: even_count,
      odd: odd_count,
      low: low_count,
      high: high_count
    })
  end

  defp build_main_pools(main_rules) do
    all_numbers = MapSet.new(1..50)
    blacklist_set = MapSet.new(main_rules.blacklist || [])
    available_numbers = MapSet.difference(all_numbers, blacklist_set)

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

    result = []
    result = add_numbers_by_constraint(result, even_needed, &(rem(&1, 2) == 0), 1..50)
    result = add_numbers_by_constraint(result, odd_needed, &(rem(&1, 2) == 1), 1..50)
    result = add_numbers_by_constraint(result, low_needed, &(&1 <= 25), 1..50)
    result = add_numbers_by_constraint(result, high_needed, &(&1 > 25), 1..50)

    # Fill remaining slots with random numbers
    remaining = 5 - length(result)

    if remaining > 0 do
      available = 1..50 |> Enum.reject(&(&1 in result))
      result ++ Enum.take_random(available, remaining)
    else
      Enum.take(result, 5)
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
    low_satisfies = constraints.low > 0 && num <= 25
    high_satisfies = constraints.high > 0 && num > 25
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
    if number <= 25 do
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

  ## Euro Numbers (2 from 1-12)

  defp generate_euro_numbers(euro_rules, precomputed_pools) do
    pools = precomputed_pools || build_euro_pools(euro_rules)
    [even_count, odd_count] = euro_rules.ratio_even_odd
    weights_map = weights_to_map(euro_rules.weights, [:hot, :random])

    generate_euro_with_constraints(pools, weights_map, 2, %{
      even: even_count,
      odd: odd_count
    })
  end

  defp build_euro_pools(euro_rules) do
    all_numbers = MapSet.new(1..12)
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

    result = []
    result = add_numbers_by_constraint(result, even_needed, &(rem(&1, 2) == 0), 1..12)
    result = add_numbers_by_constraint(result, odd_needed, &(rem(&1, 2) == 1), 1..12)

    # Fill remaining slots
    remaining = 2 - length(result)

    if remaining > 0 do
      available = 1..12 |> Enum.reject(&(&1 in result))
      result ++ Enum.take_random(available, remaining)
    else
      Enum.take(result, 2)
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

  defp validate_result(%{main: main, euro: euro}, rules) do
    with :ok <- validate_main_numbers(main, rules.main_numbers),
         :ok <- validate_euro_numbers(euro, rules.euro_numbers) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_main_numbers(numbers, main_rules) do
    cond do
      length(numbers) != 5 ->
        {:error, :invalid_count}

      not Enum.all?(numbers, &(&1 in 1..50)) ->
        {:error, :out_of_range}

      length(Enum.uniq(numbers)) != 5 ->
        {:error, :duplicates}

      not validate_ratios(numbers, main_rules) ->
        {:error, :constraints_not_satisfied}

      true ->
        :ok
    end
  end

  defp validate_euro_numbers(numbers, euro_rules) do
    cond do
      length(numbers) != 2 ->
        {:error, :invalid_count}

      not Enum.all?(numbers, &(&1 in 1..12)) ->
        {:error, :out_of_range}

      length(Enum.uniq(numbers)) != 2 ->
        {:error, :duplicates}

      not validate_euro_ratios(numbers, euro_rules) ->
        {:error, :constraints_not_satisfied}

      true ->
        :ok
    end
  end

  defp validate_ratios(numbers, main_rules) do
    [even_target, odd_target] = main_rules.ratio_even_odd
    [low_target, high_target] = main_rules.ratio_low_high

    even_count = Enum.count(numbers, &(rem(&1, 2) == 0))
    odd_count = Enum.count(numbers, &(rem(&1, 2) == 1))
    low_count = Enum.count(numbers, &(&1 <= 25))
    high_count = Enum.count(numbers, &(&1 > 25))

    even_count == even_target &&
      odd_count == odd_target &&
      low_count == low_target &&
      high_count == high_target
  end

  defp validate_euro_ratios(numbers, euro_rules) do
    [even_target, odd_target] = euro_rules.ratio_even_odd

    even_count = Enum.count(numbers, &(rem(&1, 2) == 0))
    odd_count = Enum.count(numbers, &(rem(&1, 2) == 1))

    even_count == even_target && odd_count == odd_target
  end
end
