defmodule NumbersEvolution.Simulations.SimulationResult do
  @moduledoc """
  Embedded schema for simulation results (stored as JSONB in simulations.result).

  Contains details about successful matches or timeout/error information.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          matched_main: [integer()] | nil,
          matched_euro: [integer()] | nil,
          attempts_count: integer() | nil,
          reason: String.t() | nil,
          limit_reached: String.t() | nil,
          error_message: String.t() | nil,
          final_draw: final_draw() | nil,
          duplicates_skipped: integer() | nil,
          unique_attempts: integer() | nil
        }

  @type final_draw :: %{
          main_numbers: [integer()],
          euro_numbers: [integer()]
        }

  @primary_key false
  embedded_schema do
    # Success fields
    field :matched_main, {:array, :integer}
    field :matched_euro, {:array, :integer}
    field :attempts_count, :integer

    # Timeout/Error fields
    field :reason, :string
    field :limit_reached, :string
    field :error_message, :string

    # Duplicate tracking fields
    field :duplicates_skipped, :integer
    field :unique_attempts, :integer

    embeds_one :final_draw, FinalDraw, primary_key: false do
      field :main_numbers, {:array, :integer}
      field :euro_numbers, {:array, :integer}
    end
  end

  @doc """
  Changeset for success result.
  """
  def success_changeset(result, attrs) do
    result
    |> cast(attrs, [
      :matched_main,
      :matched_euro,
      :attempts_count,
      :duplicates_skipped,
      :unique_attempts
    ])
    |> validate_required([:matched_main, :matched_euro, :attempts_count])
    |> cast_embed(:final_draw, required: true, with: &final_draw_changeset/2)
    |> validate_number(:attempts_count, greater_than: 0)
    |> validate_number(:duplicates_skipped, greater_than_or_equal_to: 0)
    |> validate_number(:unique_attempts, greater_than: 0)
  end

  @doc """
  Changeset for timeout/error result.
  """
  def timeout_changeset(result, attrs) do
    result
    |> cast(attrs, [
      :reason,
      :limit_reached,
      :attempts_count,
      :error_message,
      :duplicates_skipped,
      :unique_attempts
    ])
    |> validate_required([:reason, :limit_reached])
    |> validate_inclusion(:reason, ~w(timeout error))
    |> validate_inclusion(:limit_reached, ~w(max_attempts time_limit))
    |> validate_number(:duplicates_skipped, greater_than_or_equal_to: 0)
    |> validate_number(:unique_attempts, greater_than_or_equal_to: 0)
  end

  @doc """
  General changeset that determines type based on fields.
  """
  def changeset(result, attrs) do
    cond do
      Map.has_key?(attrs, "matched_main") || Map.has_key?(attrs, :matched_main) ->
        success_changeset(result, attrs)

      Map.has_key?(attrs, "reason") || Map.has_key?(attrs, :reason) ->
        timeout_changeset(result, attrs)

      true ->
        result
        |> cast(attrs, [])
        |> add_error(:base, "invalid result format")
    end
  end

  defp final_draw_changeset(final_draw, attrs) do
    final_draw
    |> cast(attrs, [:main_numbers, :euro_numbers])
    |> validate_required([:main_numbers, :euro_numbers])
    |> validate_length(:main_numbers, is: 5)
    |> validate_length(:euro_numbers, is: 2)
  end
end
