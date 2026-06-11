defmodule NumbersEvolution.Draws.DrawNumbers do
  @moduledoc """
  Embedded schema for lottery draw numbers (stored as JSONB in draws.numbers).

  Contains the actual drawn numbers for main and bonus (euro) numbers.
  Validation depends on the parent draw's game type (see `NumbersEvolution.Games`):
  Eurojackpot requires 5 main + 2 euro numbers, Lotto 6 main and no euro numbers.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias NumbersEvolution.Games

  @type t :: %__MODULE__{
          main_numbers: [integer()],
          euro_numbers: [integer()]
        }

  @primary_key false
  embedded_schema do
    field(:main_numbers, {:array, :integer})
    field(:euro_numbers, {:array, :integer}, default: [])
  end

  @doc """
  Changeset for draw numbers with game-specific validation.
  """
  def changeset(numbers, attrs, game_id \\ Games.default_id()) do
    game = Games.get!(game_id)

    numbers
    |> cast(attrs, [:main_numbers, :euro_numbers])
    |> validate_required([:main_numbers])
    |> update_change(:euro_numbers, &(&1 || []))
    |> validate_numbers(:main_numbers, game.main.count, game.main.min..game.main.max)
    |> validate_euro_numbers(game)
  end

  defp validate_euro_numbers(changeset, %{bonus: %{count: 0}}) do
    validate_change(changeset, :euro_numbers, fn :euro_numbers, numbers ->
      if numbers in [nil, []] do
        []
      else
        [euro_numbers: "must be empty for this game"]
      end
    end)
  end

  defp validate_euro_numbers(changeset, game) do
    changeset
    |> validate_required([:euro_numbers])
    |> validate_numbers(:euro_numbers, game.bonus.count, game.bonus.min..game.bonus.max)
  end

  defp validate_numbers(changeset, field, count, range) do
    validate_change(changeset, field, fn ^field, numbers ->
      cond do
        !is_list(numbers) ->
          [{field, "must be a list"}]

        length(numbers) != count ->
          [{field, "must contain exactly #{count} numbers, got #{length(numbers)}"}]

        !Enum.all?(numbers, &is_integer/1) ->
          [{field, "all values must be integers"}]

        !Enum.all?(numbers, &(&1 in range)) ->
          [{field, "all numbers must be in range #{range.first}-#{range.last}"}]

        length(Enum.uniq(numbers)) != count ->
          [{field, "all numbers must be unique"}]

        numbers != Enum.sort(numbers) ->
          [{field, "numbers must be sorted in ascending order"}]

        true ->
          []
      end
    end)
  end
end
