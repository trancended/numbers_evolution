defmodule NumbersEvolution.Games do
  @moduledoc """
  Single source of truth for supported lottery games.

  Each game defines its number format (main + optional bonus numbers),
  prize tiers, VIP-mode parameters and import configuration. All code that
  previously hardcoded Eurojackpot constants (5/50, 2/12, tiers, pool sizes)
  reads from this module instead.

  `multi_multi` is a valid `game_type` on draws but has no configuration
  here yet - it is intentionally out of scope (see .ai/lotto-game-implementation-plan.md).
  """

  @type game :: %{
          id: String.t(),
          label: String.t(),
          main: %{
            count: pos_integer(),
            min: pos_integer(),
            max: pos_integer(),
            low_max: pos_integer()
          },
          bonus: %{count: non_neg_integer(), min: non_neg_integer(), max: non_neg_integer()},
          prize_tiers: %{{non_neg_integer(), non_neg_integer()} => pos_integer()},
          ticket_cost: float(),
          payouts: %{pos_integer() => number()},
          vip: %{
            pool_main: pos_integer(),
            pool_bonus: non_neg_integer(),
            parity_odd: pos_integer(),
            parity_even: pos_integer(),
            blacklist_main: pos_integer(),
            blacklist_bonus: non_neg_integer()
          },
          search_space: pos_integer(),
          import:
            %{type: :lottoland, api_path: String.t()}
            | %{type: :archive, url: String.t()}
            | nil
        }

  @games %{
    "eurojackpot" => %{
      id: "eurojackpot",
      label: "Eurojackpot",
      main: %{count: 5, min: 1, max: 50, low_max: 25},
      bonus: %{count: 2, min: 1, max: 12},
      prize_tiers: %{
        # I (5+2)
        {5, 2} => 1,
        # II (5+1)
        {5, 1} => 2,
        # III (5+0)
        {5, 0} => 3,
        # IV (4+2)
        {4, 2} => 4,
        # V (4+1)
        {4, 1} => 5,
        # VI (3+2)
        {3, 2} => 6,
        # VII (4+0)
        {4, 0} => 7,
        # VIII (2+2)
        {2, 2} => 8,
        # IX (3+1)
        {3, 1} => 9,
        # X (3+0)
        {3, 0} => 10,
        # XI (1+2)
        {1, 2} => 11,
        # XII (2+1)
        {2, 1} => 12
      },
      # Cena kuponu (PLN) i orientacyjne, uśrednione wypłaty per stopień (PLN).
      # Wartości są PRZYBLIŻENIEM (pule I-III są zmienne, zależne od losowania) —
      # służą do szacowania EV/ROI, nie jako gwarancja. Można je nadpisać per gra.
      ticket_cost: 12.5,
      payouts: %{
        1 => 40_000_000,
        2 => 2_000_000,
        3 => 200_000,
        4 => 5_000,
        5 => 300,
        6 => 200,
        7 => 130,
        8 => 50,
        9 => 40,
        10 => 30,
        11 => 25,
        12 => 20
      },
      vip: %{
        pool_main: 25,
        pool_bonus: 6,
        parity_odd: 2,
        parity_even: 3,
        blacklist_main: 25,
        blacklist_bonus: 6
      },
      # C(50,5) * C(12,2)
      search_space: 139_838_160,
      import: %{type: :lottoland, api_path: "euroJackpot"}
    },
    "lotto" => %{
      id: "lotto",
      label: "Lotto",
      main: %{count: 6, min: 1, max: 49, low_max: 25},
      bonus: %{count: 0, min: 0, max: 0},
      prize_tiers: %{
        # szóstka
        {6, 0} => 1,
        # piątka
        {5, 0} => 2,
        # czwórka
        {4, 0} => 3,
        # trójka
        {3, 0} => 4
      },
      # Cena kuponu (PLN) i orientacyjne, uśrednione wypłaty per stopień (PLN).
      # Szóstka jest zmienną kumulacją - podana wartość jest reprezentatywna.
      ticket_cost: 3.0,
      payouts: %{
        1 => 6_000_000,
        2 => 5_000,
        3 => 150,
        4 => 24
      },
      vip: %{
        # ceil(49 / 2) - rounding up keeps the "pool contains target" retry viable
        pool_main: 25,
        pool_bonus: 0,
        parity_odd: 3,
        parity_even: 3,
        # floor(49 / 2)
        blacklist_main: 24,
        blacklist_bonus: 0
      },
      # C(49,6)
      search_space: 13_983_816,
      # Full draw archive since 1957, one line per draw, updated after each
      # drawing. Lottoland's polishLotto endpoint is unreliable: between draws
      # its "last" points at the upcoming drawing with numbers: nil.
      # HTTPS on mbnet serves a mismatched certificate, hence plain HTTP.
      import: %{type: :archive, url: "http://www.mbnet.com.pl/dl.txt"}
    }
  }

  @default_id "eurojackpot"

  @doc "Returns the list of supported game ids."
  @spec ids() :: [String.t()]
  def ids, do: ["eurojackpot", "lotto"]

  @doc "Returns the default game id (used wherever no game was selected)."
  @spec default_id() :: String.t()
  def default_id, do: @default_id

  @doc "Returns the configuration for a game id, raising for unknown games."
  @spec get!(String.t() | game()) :: game()
  def get!(%{id: _} = game), do: game
  def get!(game_id) when is_binary(game_id), do: Map.fetch!(@games, game_id)

  @doc "Returns the configuration for the default game."
  @spec default() :: game()
  def default, do: get!(@default_id)

  @doc "Returns true when the game id has a configuration."
  @spec supported?(String.t()) :: boolean()
  def supported?(game_id), do: Map.has_key?(@games, game_id)

  @doc "Returns the human-readable label for a game."
  @spec label(String.t() | game()) :: String.t()
  def label(game), do: get!(game).label

  @doc "Returns true when the game uses bonus (euro) numbers."
  @spec has_bonus?(String.t() | game()) :: boolean()
  def has_bonus?(game), do: get!(game).bonus.count > 0

  @doc "Returns the ticket cost (PLN) for a game."
  @spec ticket_cost(String.t() | game()) :: float()
  def ticket_cost(game), do: get!(game).ticket_cost

  @doc "Returns the approximate per-tier payout table (tier number => PLN)."
  @spec payouts(String.t() | game()) :: %{pos_integer() => number()}
  def payouts(game), do: get!(game).payouts

  @doc "Returns `{label, id}` options for game `<select>` inputs."
  @spec select_options() :: [{String.t(), String.t()}]
  def select_options do
    Enum.map(ids(), fn id -> {label(id), id} end)
  end

  @doc "Returns games that can be imported from the public API."
  @spec importable() :: [game()]
  def importable do
    ids() |> Enum.map(&get!/1) |> Enum.filter(& &1.import)
  end
end
