defmodule NumbersEvolution.Draws.DrawNumbers do
  @moduledoc """
  Embedded schema for lottery draw numbers (stored as JSONB in draws.numbers).

  Contains the actual drawn numbers for main and euro numbers.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          main_numbers: [integer()],
          euro_numbers: [integer()]
        }

  @primary_key false
  embedded_schema do
    field(:main_numbers, {:array, :integer})
    field(:euro_numbers, {:array, :integer})
  end

  @doc """
  Changeset for draw numbers with validation.
  """
  def changeset(numbers, attrs) do
    numbers
    |> cast(attrs, [:main_numbers, :euro_numbers])
    |> validate_required([:main_numbers, :euro_numbers])
    |> validate_main_numbers()
    |> validate_euro_numbers()
  end

  defp validate_main_numbers(changeset) do
    validate_change(changeset, :main_numbers, fn :main_numbers, numbers ->
      cond do
        !is_list(numbers) ->
          [main_numbers: "must be a list"]

        length(numbers) != 5 ->
          [main_numbers: "must contain exactly 5 numbers, got #{length(numbers)}"]

        !Enum.all?(numbers, &is_integer/1) ->
          [main_numbers: "all values must be integers"]

        !Enum.all?(numbers, &(&1 in 1..50)) ->
          [main_numbers: "all numbers must be in range 1-50"]

        length(Enum.uniq(numbers)) != 5 ->
          [main_numbers: "all numbers must be unique"]

        numbers != Enum.sort(numbers) ->
          [main_numbers: "numbers must be sorted in ascending order"]

        true ->
          []
      end
    end)
  end

  defp validate_euro_numbers(changeset) do
    validate_change(changeset, :euro_numbers, fn :euro_numbers, numbers ->
      cond do
        !is_list(numbers) ->
          [euro_numbers: "must be a list"]

        length(numbers) != 2 ->
          [euro_numbers: "must contain exactly 2 numbers, got #{length(numbers)}"]

        !Enum.all?(numbers, &is_integer/1) ->
          [euro_numbers: "all values must be integers"]

        !Enum.all?(numbers, &(&1 in 1..12)) ->
          [euro_numbers: "all numbers must be in range 1-12"]

        length(Enum.uniq(numbers)) != 2 ->
          [euro_numbers: "all numbers must be unique"]

        numbers != Enum.sort(numbers) ->
          [euro_numbers: "numbers must be sorted in ascending order"]

        true ->
          []
      end
    end)
  end
end
