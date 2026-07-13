defmodule NumbersEvolution.Simulations.Algorithm.Annealing do
  @moduledoc """
  ALG-6 — Guided simulated-annealing search.

  A fundamentally different engine from blind i.i.d. sampling: it treats a
  combination as a state whose *energy* is the number of target numbers still
  unmatched, and does a temperature-controlled random walk (Metropolis
  acceptance) that converges on the target in a handful of *guided* steps rather
  than the ~140M a blind search needs.

  Like VIP modes this consumes target information, so it measures "how fast can a
  guided search converge", not fair-game odds — consistent with the intentional
  look-ahead. Implements `NumbersEvolution.Simulations.Algorithm`.

  `init/2` opts:
  - `:target` — required `%{main: [...], euro: [...]}`
  - `:temp` (default 2.0), `:cooling` (default 0.995), `:min_temp` (default 0.05)
  - `:seed` — reproducible walk
  """

  @behaviour NumbersEvolution.Simulations.Algorithm

  @impl true
  def init(game, opts) do
    target = Keyword.fetch!(opts, :target)
    if opts[:seed], do: :rand.seed(:exsss, opts[:seed])

    main_pool = Enum.to_list(game.main.min..game.main.max)
    euro_pool = euro_pool(game)

    main = Enum.take_random(main_pool, game.main.count)
    euro = Enum.take_random(euro_pool, game.bonus.count)

    %{
      main: main,
      euro: euro,
      main_pool: main_pool,
      euro_pool: euro_pool,
      target_main: MapSet.new(target.main),
      target_euro: MapSet.new(target.euro),
      temp: Keyword.get(opts, :temp, 2.0),
      cooling: Keyword.get(opts, :cooling, 0.995),
      min_temp: Keyword.get(opts, :min_temp, 0.05),
      energy: nil
    }
    |> put_energy()
  end

  @impl true
  def next(state) do
    {cand_main, cand_euro} = neighbor(state)
    cand_energy = energy(cand_main, cand_euro, state)
    state = accept(state, cand_main, cand_euro, cand_energy)
    {%{main: Enum.sort(state.main), euro: Enum.sort(state.euro)}, cool(state)}
  end

  @doc """
  Runs the walk until the target is fully matched (energy 0) or `max_steps` is
  exhausted. Returns `%{combo, steps, hit?, final_energy}`.
  """
  @spec search(map(), map(), keyword()) :: map()
  def search(target, game, opts \\ []) do
    max_steps = Keyword.get(opts, :max_steps, 100_000)
    state = init(game, Keyword.put(opts, :target, target))
    walk(state, 0, max_steps)
  end

  defp walk(%{energy: 0} = state, steps, _max), do: result(state, steps, true)
  defp walk(state, steps, max) when steps >= max, do: result(state, steps, false)

  defp walk(state, steps, max) do
    {_combo, next_state} = next(state)
    walk(next_state, steps + 1, max)
  end

  defp result(state, steps, hit?) do
    %{
      combo: %{main: Enum.sort(state.main), euro: Enum.sort(state.euro)},
      steps: steps,
      hit?: hit?,
      final_energy: state.energy
    }
  end

  # Swap one selected number (main or euro) for a random unselected one.
  defp neighbor(state) do
    if state.euro != [] and :rand.uniform() < euro_share(state) do
      {state.main, swap_one(state.euro, state.euro_pool)}
    else
      {swap_one(state.main, state.main_pool), state.euro}
    end
  end

  defp euro_share(state) do
    total = length(state.main) + length(state.euro)
    length(state.euro) / total
  end

  defp swap_one(selected, pool) do
    outgoing = Enum.random(selected)
    incoming = pool |> Enum.reject(&(&1 in selected)) |> Enum.random()
    [incoming | List.delete(selected, outgoing)]
  end

  # Metropolis: always accept improvements; accept worse moves with Boltzmann prob.
  defp accept(state, cand_main, cand_euro, cand_energy) do
    delta = cand_energy - state.energy

    if delta <= 0 or :rand.uniform() < :math.exp(-delta / state.temp) do
      %{state | main: cand_main, euro: cand_euro, energy: cand_energy}
    else
      state
    end
  end

  defp cool(state), do: %{state | temp: max(state.temp * state.cooling, state.min_temp)}

  defp put_energy(state), do: %{state | energy: energy(state.main, state.euro, state)}

  defp energy(main, euro, state) do
    main_miss = length(main) - count_in(main, state.target_main)
    euro_miss = length(euro) - count_in(euro, state.target_euro)
    main_miss + euro_miss
  end

  defp count_in(numbers, set), do: Enum.count(numbers, &MapSet.member?(set, &1))

  defp euro_pool(%{bonus: %{count: 0}}), do: []
  defp euro_pool(game), do: Enum.to_list(game.bonus.min..game.bonus.max)
end
