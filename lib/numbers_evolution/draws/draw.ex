defmodule NumbersEvolution.Draws.Draw do
  @moduledoc """
  Draw schema for historical lottery draw results.

  Public resource - no user scoping required.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias NumbersEvolution.Draws.DrawNumbers
  alias NumbersEvolution.Games
  alias NumbersEvolution.Simulations.Simulation

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          draw_date: Date.t(),
          game_type: String.t(),
          numbers: DrawNumbers.t(),
          source: String.t() | nil,
          simulations: [Simulation.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @valid_game_types ~w(eurojackpot lotto multi_multi)
  @valid_sources ~w(manual import admin)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "draws" do
    field(:draw_date, :date)
    field(:game_type, :string)
    field(:source, :string)

    embeds_one(:numbers, DrawNumbers)

    has_many(:simulations, Simulation, foreign_key: :target_draw_id)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a draw.
  """
  def changeset(draw, attrs) do
    changeset =
      draw
      |> cast(attrs, [:draw_date, :game_type, :source])
      |> validate_required([:draw_date, :game_type])
      |> validate_inclusion(:game_type, @valid_game_types)
      |> validate_inclusion(:source, @valid_sources)

    game_id = numbers_game_id(changeset)

    changeset
    |> cast_embed(:numbers,
      required: true,
      with: fn numbers, numbers_attrs ->
        DrawNumbers.changeset(numbers, numbers_attrs, game_id)
      end
    )
    |> validate_draw_date()
    |> unique_constraint([:game_type, :draw_date], name: :draws_game_date_unique)
  end

  # Numbers are validated against the draw's game; game types without a
  # configuration (multi_multi) keep the historical default format
  defp numbers_game_id(changeset) do
    case get_field(changeset, :game_type) do
      game_type when is_binary(game_type) ->
        if Games.supported?(game_type), do: game_type, else: Games.default_id()

      _ ->
        Games.default_id()
    end
  end

  defp validate_draw_date(changeset) do
    validate_change(changeset, :draw_date, fn :draw_date, draw_date ->
      today = Date.utc_today()

      if Date.compare(draw_date, today) == :gt do
        [draw_date: "cannot be in the future"]
      else
        []
      end
    end)
  end
end
