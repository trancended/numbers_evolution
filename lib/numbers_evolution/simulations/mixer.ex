defmodule NumbersEvolution.Simulations.Mixer do
  @moduledoc """
  Portfolio orchestrator that **mixes** candidate-generating engines
  (`Algorithm` implementations) under a Thompson-sampling bandit
  (`Optimizer.Bandit`). Each round the bandit picks an engine, pulls one
  candidate from it, and is rewarded by how many target numbers that candidate
  matched — so budget flows automatically to whichever engine is converging
  fastest, with no hand-tuned schedule.

  This is the concrete realization of "we can mix the algorithms": drop any set
  of engines into `run/4` and the mixer self-allocates between them.
  """

  alias NumbersEvolution.Simulations.Optimizer.Bandit

  @type engine_spec :: {name :: atom(), module :: module(), init_opts :: keyword()}

  @doc """
  Mix `engines` toward `target` for a budget, rewarding by match count.

  `engines` is a list of `{name, module, init_opts}`. Returns a summary with the
  winning engine, whether the jackpot was reached, and per-engine bandit stats.

  `opts`: `:budget` (default 20_000), `:seed`.
  """
  @spec run([engine_spec()], map(), map(), keyword()) :: map()
  def run(engines, target, game, opts \\ []) do
    budget = Keyword.get(opts, :budget, 20_000)
    if opts[:seed], do: :rand.seed(:exsss, opts[:seed])

    states = Map.new(engines, fn {name, mod, init} -> {name, {mod, mod.init(game, init)}} end)
    bandit = Bandit.new(Enum.map(engines, fn {name, _m, _o} -> name end))
    total = length(target.main) + length(target.euro)

    loop(%{
      states: states,
      bandit: bandit,
      target: target,
      total: total,
      step: 0,
      budget: budget,
      best: %{matches: -1, combo: nil}
    })
  end

  defp loop(%{step: step, budget: budget} = ctx) when step >= budget, do: summarize(ctx, false)

  defp loop(ctx) do
    name = Bandit.select(ctx.bandit)
    {mod, state} = Map.fetch!(ctx.states, name)
    {combo, next_state} = mod.next(state)

    matches = count_matches(combo, ctx.target)
    ctx = advance(ctx, name, mod, next_state, combo, matches)

    if matches == ctx.total, do: summarize(ctx, true), else: loop(ctx)
  end

  defp advance(ctx, name, mod, next_state, combo, matches) do
    %{
      ctx
      | states: Map.put(ctx.states, name, {mod, next_state}),
        bandit: Bandit.reward(ctx.bandit, name, matches / ctx.total),
        step: ctx.step + 1,
        best: best_of(ctx.best, matches, combo)
    }
  end

  defp best_of(%{matches: bm} = best, matches, _combo) when matches <= bm, do: best
  defp best_of(_best, matches, combo), do: %{matches: matches, combo: combo}

  defp count_matches(combo, target) do
    main = Enum.count(combo.main, &(&1 in target.main))
    euro = Enum.count(combo.euro, &(&1 in target.euro))
    main + euro
  end

  defp summarize(ctx, hit?) do
    %{
      winner: Bandit.best(ctx.bandit),
      hit?: hit?,
      steps: ctx.step,
      best_matches: ctx.best.matches,
      best_combo: ctx.best.combo,
      bandit_stats: Bandit.stats(ctx.bandit)
    }
  end
end
