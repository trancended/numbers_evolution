defmodule NumbersEvolution.Simulations.Algorithm.QuasiRandom do
  @moduledoc """
  ALG-7 — Low-discrepancy (quasi-random) combination generator.

  Replaces i.i.d. sampling with an evenly spread sequence over the *combination
  index space* `[0, C(n, k))`. Indices come from a golden-ratio additive
  recurrence (maximal 1-D uniformity, no clustering that dedup can't fix), and
  each index is turned into a concrete k-combination via the combinatorial
  number system (`unrank/2`). Coverage is guaranteed even and fully
  reproducible.

  Implements `NumbersEvolution.Simulations.Algorithm`.

  `init/2` opts:
  - `:start` — starting sequence index (default 0)
  - `:offset` — fractional scramble in `0.0..1.0` to decorrelate runs (default 0)
  """

  @behaviour NumbersEvolution.Simulations.Algorithm

  alias NumbersEvolution.Analytics

  # (sqrt(5)-1)/2 and sqrt(2)-1 — irrational, so the recurrences never repeat and
  # stay maximally spread; different constants decorrelate main vs euro.
  @phi_main 0.6180339887498949
  @phi_euro 0.41421356237309515

  @impl true
  def init(game, opts) do
    %{
      game: game,
      i: Keyword.get(opts, :start, 0),
      offset: Keyword.get(opts, :offset, 0.0),
      space_main: Analytics.comb(main_n(game), game.main.count),
      space_euro: euro_space(game)
    }
  end

  @impl true
  def next(state) do
    {at(state.i, state), %{state | i: state.i + 1}}
  end

  @doc "The i-th quasi-random combination for the given engine state."
  @spec at(non_neg_integer(), map()) :: %{main: [pos_integer()], euro: [pos_integer()]}
  def at(i, state) do
    game = state.game
    main_idx = sequence_index(i, @phi_main, state.offset, state.space_main)
    euro_idx = sequence_index(i, @phi_euro, state.offset, state.space_euro)

    %{
      main: combination(main_idx, game.main.count, game.main.min),
      euro: euro_combination(euro_idx, game)
    }
  end

  @doc "Convenience: the first `count` quasi-random combinations for a game."
  @spec take(non_neg_integer(), map(), keyword()) :: [map()]
  def take(count, game, opts \\ []) do
    state = init(game, opts)
    Enum.map(0..(count - 1), fn i -> at(state.i + i, state) end)
  end

  @doc """
  Unranks index `m` into a k-combination of 0-based numbers via the combinatorial
  number system (returned ascending).
  """
  @spec unrank(non_neg_integer(), pos_integer()) :: [non_neg_integer()]
  def unrank(m, k) do
    {digits, _rest} =
      Enum.map_reduce(k..1//-1, m, fn j, remaining ->
        c = largest_c(j, remaining)
        {c, remaining - Analytics.comb(c, j)}
      end)

    Enum.sort(digits)
  end

  # Golden-ratio additive recurrence mapped into [0, space).
  defp sequence_index(_i, _phi, _offset, 0), do: 0

  defp sequence_index(i, phi, offset, space) do
    x = (i + 1) * phi + offset
    frac = x - Float.floor(x)
    min(trunc(frac * space), space - 1)
  end

  defp combination(index, k, minimum) do
    index |> unrank(k) |> Enum.map(&(&1 + minimum))
  end

  defp euro_combination(_index, %{bonus: %{count: 0}}), do: []
  defp euro_combination(index, game), do: combination(index, game.bonus.count, game.bonus.min)

  # Largest c with C(c, j) <= m (C is increasing in c for c >= j).
  defp largest_c(j, m), do: grow_c(j - 1, j, m)

  defp grow_c(c, j, m) do
    if Analytics.comb(c + 1, j) <= m, do: grow_c(c + 1, j, m), else: c
  end

  defp main_n(game), do: game.main.max - game.main.min + 1

  defp euro_space(%{bonus: %{count: 0}}), do: 0
  defp euro_space(game), do: Analytics.comb(game.bonus.max - game.bonus.min + 1, game.bonus.count)
end
