defmodule NumbersEvolution.Strategies.StrategyRules do
  @moduledoc """
  Embedded schema for strategy rules (stored as JSONB in strategies.rules).

  Defines the structure for how numbers should be generated according to strategy.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          main_numbers: main_numbers(),
          euro_numbers: euro_numbers()
        }

  @type main_numbers :: %{
          ratio_even_odd: [integer()],
          ratio_low_high: [integer()],
          preferred_hot: [integer()],
          preferred_cold: [integer()],
          weights: weights()
        }

  @type euro_numbers :: %{
          ratio_even_odd: [integer()],
          preferred: [integer()],
          weights: weights()
        }

  @type weights :: %{
          hot: float(),
          cold: float(),
          random: float()
        }

  @primary_key false
  embedded_schema do
    embeds_one :main_numbers, MainNumbers, primary_key: false do
      field :ratio_even_odd, {:array, :integer}
      field :ratio_low_high, {:array, :integer}
      field :preferred_hot, {:array, :integer}
      field :preferred_cold, {:array, :integer}

      embeds_one :weights, Weights, primary_key: false do
        field :hot, :float
        field :cold, :float
        field :random, :float
      end
    end

    embeds_one :euro_numbers, EuroNumbers, primary_key: false do
      field :ratio_even_odd, {:array, :integer}
      field :preferred, {:array, :integer}

      embeds_one :weights, Weights, primary_key: false do
        field :hot, :float
        field :random, :float
      end
    end
  end

  @doc """
  Changeset for strategy rules with comprehensive validation.
  """
  def changeset(rules, attrs) do
    rules
    |> cast(attrs, [])
    |> cast_embed(:main_numbers, required: true, with: &main_numbers_changeset/2)
    |> cast_embed(:euro_numbers, required: true, with: &euro_numbers_changeset/2)
  end

  defp main_numbers_changeset(main_numbers, attrs) do
    main_numbers
    |> cast(attrs, [:ratio_even_odd, :ratio_low_high, :preferred_hot, :preferred_cold])
    |> validate_required([:ratio_even_odd, :ratio_low_high])
    |> cast_embed(:weights, required: true, with: &main_weights_changeset/2)
    |> validate_ratio_sum(:ratio_even_odd, 5)
    |> validate_ratio_sum(:ratio_low_high, 5)
    |> validate_number_range(:preferred_hot, 1..50)
    |> validate_number_range(:preferred_cold, 1..50)
  end

  defp euro_numbers_changeset(euro_numbers, attrs) do
    euro_numbers
    |> cast(attrs, [:ratio_even_odd, :preferred])
    |> validate_required([:ratio_even_odd])
    |> cast_embed(:weights, required: true, with: &euro_weights_changeset/2)
    |> validate_ratio_sum(:ratio_even_odd, 2)
    |> validate_number_range(:preferred, 1..12)
  end

  defp main_weights_changeset(weights, attrs) do
    weights
    |> cast(attrs, [:hot, :cold, :random])
    |> validate_required([:hot, :cold, :random])
    |> validate_number(:hot, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:cold, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:random, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_weights_sum()
  end

  defp euro_weights_changeset(weights, attrs) do
    weights
    |> cast(attrs, [:hot, :random])
    |> validate_required([:hot, :random])
    |> validate_number(:hot, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:random, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_weights_sum()
  end

  # Custom validators

  defp validate_ratio_sum(changeset, field, expected_sum) do
    validate_change(changeset, field, fn ^field, ratio ->
      case ratio do
        [a, b] when is_integer(a) and is_integer(b) and a >= 0 and b >= 0 ->
          if a + b == expected_sum do
            []
          else
            [{field, "must sum to #{expected_sum}, got #{a + b}"}]
          end

        _ ->
          [{field, "must be a list of two non-negative integers"}]
      end
    end)
  end

  defp validate_number_range(changeset, field, range) do
    validate_change(changeset, field, fn ^field, numbers ->
      if is_list(numbers) && Enum.all?(numbers, &(&1 in range)) do
        []
      else
        [{field, "all numbers must be in range #{inspect(range)}"}]
      end
    end)
  end

  defp validate_weights_sum(changeset) do
    case changeset do
      %{valid?: true, changes: changes} ->
        weights_map = Map.take(changes, [:hot, :cold, :random])

        if map_size(weights_map) > 0 do
          sum =
            weights_map
            |> Map.values()
            |> Enum.sum()

          tolerance = 0.001

          if abs(sum - 1.0) < tolerance do
            changeset
          else
            add_error(
              changeset,
              :weights,
              "must sum to 1.0 (±0.001 tolerance), got #{Float.round(sum, 3)}"
            )
          end
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end
