defmodule NumbersEvolution.Strategies.Generator do
  @moduledoc """
  Generates Eurojackpot number combinations based on strategy rules.

  The generator applies strategy rules including:
  - Even/odd ratios
  - Low/high ratios (for main numbers)
  - Preferred hot/cold numbers
  - Weighted pool selection (hot/cold/random)
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

    # Check if this is the special "half random" strategy or half_random_mode is enabled
    if String.contains?(name, "Losowo pomin połowę") or half_random_mode do
      generate_half_random_strategy(strategy)
    else
      generate_numbers_standard(strategy)
    end
  end

  defp generate_numbers_standard(%Strategy{rules: rules}) do
    main_numbers = generate_main_numbers(rules.main_numbers)
    euro_numbers = generate_euro_numbers(rules.euro_numbers)

    result = %{main: Enum.sort(main_numbers), euro: Enum.sort(euro_numbers)}

    case validate_result(result, rules) do
      :ok -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  # Special strategy: randomly omit half numbers, then select 3 odd + 2 even with max 2 per decade
  defp generate_half_random_strategy(_strategy) do
    # Main numbers: randomly select 25 out of 50
    all_main = 1..50 |> Enum.to_list()
    selected_main_pool = Enum.take_random(all_main, 25)

    # From the selected pool, get odd and even numbers
    odd_numbers = selected_main_pool |> Enum.filter(&(rem(&1, 2) == 1))
    even_numbers = selected_main_pool |> Enum.filter(&(rem(&1, 2) == 0))

    # Select 3 odd and 2 even
    selected_odd = Enum.take_random(odd_numbers, min(3, length(odd_numbers)))
    selected_even = Enum.take_random(even_numbers, min(2, length(even_numbers)))

    main_numbers = selected_odd ++ selected_even

    # If we don't have enough numbers, fill with remaining from pool
    remaining_needed = 5 - length(main_numbers)

    final_main_numbers =
      if remaining_needed > 0 do
        remaining_pool = selected_main_pool -- main_numbers
        additional = Enum.take_random(remaining_pool, remaining_needed)
        main_numbers ++ additional
      else
        main_numbers
      end

    # Ensure max 2 per decade and exactly 5 numbers
    main_numbers = enforce_decade_constraint(Enum.take_random(final_main_numbers, 5))

    # Euro numbers: randomly select 6 out of 12
    all_euro = 1..12 |> Enum.to_list()
    selected_euro_pool = Enum.take_random(all_euro, 6)

    # Select 1 odd and 1 even from the euro pool
    euro_odd = selected_euro_pool |> Enum.filter(&(rem(&1, 2) == 1))
    euro_even = selected_euro_pool |> Enum.filter(&(rem(&1, 2) == 0))

    selected_euro_odd = if length(euro_odd) > 0, do: [Enum.random(euro_odd)], else: []
    selected_euro_even = if length(euro_even) > 0, do: [Enum.random(euro_even)], else: []

    euro_numbers = selected_euro_odd ++ selected_euro_even

    # Fill to 2 numbers if needed
    final_euro_numbers =
      if length(euro_numbers) < 2 do
        remaining_euro = selected_euro_pool -- euro_numbers
        additional_euro = Enum.take_random(remaining_euro, 2 - length(euro_numbers))
        euro_numbers ++ additional_euro
      else
        euro_numbers
      end

    euro_numbers = Enum.take(final_euro_numbers, 2)

    result = %{main: Enum.sort(main_numbers), euro: Enum.sort(euro_numbers)}

    # Basic validation
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
            existing = Map.get(by_decade, decade, [])
            decade_range -- (existing -- constrained)
          end)

        additional_needed = 5 - count
        additional = Enum.take_random(available_numbers, additional_needed)
        constrained ++ additional

      _count ->
        # Too many numbers, take random 5
        Enum.take_random(constrained, 5)
    end
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

  defp generate_main_numbers(main_rules) do
    pools = build_main_pools(main_rules)
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
    hot_set = MapSet.new(main_rules.preferred_hot || [])
    cold_set = MapSet.new(main_rules.preferred_cold || [])
    random_set = MapSet.difference(all_numbers, MapSet.union(hot_set, cold_set))

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

  defp generate_euro_numbers(euro_rules) do
    pools = build_euro_pools(euro_rules)
    [even_count, odd_count] = euro_rules.ratio_even_odd
    weights_map = weights_to_map(euro_rules.weights, [:hot, :random])

    generate_euro_with_constraints(pools, weights_map, 2, %{
      even: even_count,
      odd: odd_count
    })
  end

  defp build_euro_pools(euro_rules) do
    all_numbers = MapSet.new(1..12)
    hot_set = MapSet.new(euro_rules.preferred || [])
    random_set = MapSet.difference(all_numbers, hot_set)

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
