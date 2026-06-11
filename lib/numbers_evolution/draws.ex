defmodule NumbersEvolution.Draws do
  @moduledoc """
  The Draws context.

  Handles historical lottery draw queries and hot/cold number analysis.
  All queries are public (no user scoping required).
  """

  import Ecto.Query, warn: false
  alias NumbersEvolution.Draws.Draw
  alias NumbersEvolution.Repo

  ## Queries (public - no user scoping)

  @doc """
  Returns the list of draws with optional filtering and pagination.

  ## Options

    * `:game_type` - Filter by game type ("eurojackpot", "lotto", "multi_multi")
    * `:from_date` - Get draws from this date
    * `:to_date` - Get draws until this date
    * `:page` - Page number for pagination (default: 1)
    * `:per_page` - Items per page (default: 20, max: 100)

  ## Examples

      iex> list_draws()
      [%Draw{}, ...]

      iex> list_draws(game_type: "eurojackpot", page: 2)
      [%Draw{}, ...]

  """
  @spec list_draws(keyword()) :: [Draw.t()]
  def list_draws(opts \\ []) do
    from(d in Draw)
    |> filter_by_game_type(opts[:game_type])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> order_by([d], desc: d.draw_date)
    |> paginate(opts)
    |> Repo.all()
  end

  @doc """
  Gets a single draw.

  Raises `Ecto.NoResultsError` if the Draw does not exist.

  ## Examples

      iex> get_draw!("c6a7b042-...")
      %Draw{}

      iex> get_draw!("invalid-uuid")
      ** (Ecto.NoResultsError)

  """
  @spec get_draw!(binary()) :: Draw.t()
  def get_draw!(id), do: Repo.get!(Draw, id)

  @doc """
  Gets the latest draw for a game type.

  ## Examples

      iex> get_latest_draw("eurojackpot")
      %Draw{}

      iex> get_latest_draw("unknown_game")
      nil

  """
  @spec get_latest_draw(String.t()) :: Draw.t() | nil
  def get_latest_draw(game_type) when is_binary(game_type) do
    from(d in Draw,
      where: d.game_type == ^game_type,
      order_by: [desc: d.draw_date],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Returns the set of draw dates already stored for a game type.

  Used by the importer to backfill only the missing archive entries.
  """
  @spec draw_dates(String.t()) :: MapSet.t(Date.t())
  def draw_dates(game_type) when is_binary(game_type) do
    from(d in Draw,
      where: d.game_type == ^game_type,
      select: d.draw_date
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Gets recent draws for a game type.

  ## Examples

      iex> recent_draws("eurojackpot", 32)
      [%Draw{}, ...]

  """
  @spec recent_draws(String.t(), pos_integer()) :: [Draw.t()]
  def recent_draws(game_type, limit \\ 32) when is_binary(game_type) do
    from(d in Draw,
      where: d.game_type == ^game_type,
      order_by: [desc: d.draw_date],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Counts draws with optional filters.

  ## Examples

      iex> count_draws()
      150

      iex> count_draws(game_type: "eurojackpot")
      100

  """
  @spec count_draws(keyword()) :: non_neg_integer()
  def count_draws(opts \\ []) do
    from(d in Draw)
    |> filter_by_game_type(opts[:game_type])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> Repo.aggregate(:count)
  end

  ## Analysis

  @doc """
  Analyzes hot and cold numbers for a game type over a period.

  Returns a map with main_numbers and euro_numbers analysis:
  - hot: numbers that appeared most frequently
  - cold: numbers that appeared least frequently
  - frequencies: all numbers with their frequencies

  ## Examples

      iex> analyze_hot_cold("eurojackpot", 32)
      %{
        main_numbers: %{
          hot: [%{number: 7, frequency: 12}, ...],
          cold: [%{number: 1, frequency: 2}, ...],
          frequencies: %{1 => 2, 7 => 12, ...}
        },
        euro_numbers: %{...}
      }

  """
  @spec analyze_hot_cold(String.t(), pos_integer()) :: map()
  def analyze_hot_cold(game_type, period \\ 32) do
    draws = recent_draws(game_type, period)

    if Enum.empty?(draws) do
      %{
        main_numbers: %{hot: [], cold: [], frequencies: %{}},
        euro_numbers: %{hot: [], cold: [], frequencies: %{}}
      }
    else
      %{
        main_numbers: analyze_number_pool(draws, :main_numbers, 1..50),
        euro_numbers: analyze_number_pool(draws, :euro_numbers, 1..12)
      }
    end
  end

  ## Admin (seeding)

  @doc """
  Creates a draw (admin/seeding only).

  ## Examples

      iex> create_draw(%{
        draw_date: ~D[2024-01-15],
        game_type: "eurojackpot",
        numbers: %{main_numbers: [1, 2, 3, 4, 5], euro_numbers: [1, 2]},
        source: "manual"
      })
      {:ok, %Draw{}}

  """
  @spec create_draw(map()) :: {:ok, Draw.t()} | {:error, Ecto.Changeset.t()}
  def create_draw(attrs) do
    %Draw{}
    |> Draw.changeset(attrs)
    |> Repo.insert()
  end

  ## Private Helpers

  defp filter_by_game_type(query, nil), do: query

  defp filter_by_game_type(query, game_type) when is_binary(game_type) do
    from(d in query, where: d.game_type == ^game_type)
  end

  defp filter_by_game_type(query, _), do: query

  defp filter_by_date_range(query, nil, nil), do: query

  defp filter_by_date_range(query, from_date, nil) when not is_nil(from_date) do
    from(d in query, where: d.draw_date >= ^from_date)
  end

  defp filter_by_date_range(query, nil, to_date) when not is_nil(to_date) do
    from(d in query, where: d.draw_date <= ^to_date)
  end

  defp filter_by_date_range(query, from_date, to_date) do
    from(d in query,
      where: d.draw_date >= ^from_date and d.draw_date <= ^to_date
    )
  end

  defp paginate(query, opts) do
    page = opts[:page] || 1
    per_page = min(opts[:per_page] || 20, 100)
    offset = (page - 1) * per_page

    from(d in query, limit: ^per_page, offset: ^offset)
  end

  defp analyze_number_pool(draws, field, range) do
    # Calculate frequencies
    frequencies =
      draws
      |> Enum.flat_map(fn draw ->
        draw.numbers
        |> Map.get(field, [])
      end)
      |> Enum.frequencies()

    # Ensure all numbers in range have a frequency (default 0)
    all_frequencies =
      Enum.reduce(range, frequencies, fn num, acc ->
        Map.put_new(acc, num, 0)
      end)

    # Convert to sorted list
    frequency_list =
      all_frequencies
      |> Enum.map(fn {number, frequency} -> %{number: number, frequency: frequency} end)
      |> Enum.sort_by(& &1.frequency, :desc)

    %{
      hot: Enum.take(frequency_list, 10),
      cold: Enum.reverse(Enum.take(Enum.reverse(frequency_list), 10)),
      frequencies: all_frequencies
    }
  end
end
