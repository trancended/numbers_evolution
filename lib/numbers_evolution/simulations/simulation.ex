defmodule NumbersEvolution.Simulations.Simulation do
  @moduledoc """
  Simulation schema for strategy simulation runs.

  Tracks attempts, duration, status, and results of running a strategy against a target draw.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias NumbersEvolution.Accounts.User
  alias NumbersEvolution.Draws.Draw
  alias NumbersEvolution.Simulations.SimulationResult
  alias NumbersEvolution.Strategies.Strategy

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          user_id: Ecto.UUID.t(),
          strategy_id: Ecto.UUID.t() | nil,
          target_draw_id: Ecto.UUID.t(),
          attempts_count: integer(),
          duration_seconds: float(),
          status: String.t(),
          result: SimulationResult.t() | nil,
          is_favorite: boolean(),
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          strategy: Strategy.t() | Ecto.Association.NotLoaded.t(),
          target_draw: Draw.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @valid_statuses ~w(pending running success timeout max_attempts_reached error cancelled)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "simulations" do
    field(:attempts_count, :integer, default: 0)
    field(:duration_seconds, :float, default: 0.0)
    field(:status, :string)
    field(:options, :map, default: %{})
    field(:is_favorite, :boolean, default: false)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    embeds_one(:result, SimulationResult)

    belongs_to(:user, User)
    belongs_to(:strategy, Strategy)
    belongs_to(:target_draw, Draw)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new simulation.
  """
  def changeset(simulation, attrs) do
    simulation
    |> cast(attrs, [
      :strategy_id,
      :target_draw_id,
      :status,
      :attempts_count,
      :duration_seconds,
      :options,
      :is_favorite
    ])
    |> validate_required([:strategy_id, :target_draw_id, :status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:attempts_count, greater_than_or_equal_to: 0)
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0.0)
    |> assoc_constraint(:user)
    |> assoc_constraint(:strategy)
    |> assoc_constraint(:target_draw)
  end

  @doc """
  Changeset for starting a simulation.
  """
  def start_changeset(simulation) do
    simulation
    |> change(status: "running", started_at: DateTime.truncate(DateTime.utc_now(), :second))
  end

  @doc """
  Changeset for completing a simulation.
  """
  def completion_changeset(simulation, status, attrs) when status in @valid_statuses do
    simulation
    |> cast(attrs, [:attempts_count, :duration_seconds])
    |> put_change(:status, status)
    |> put_change(:completed_at, DateTime.truncate(DateTime.utc_now(), :second))
    |> cast_embed(:result, required: status == "success")
    |> validate_completion_timing()
  end

  @doc """
  Changeset for updating progress during simulation.
  """
  def progress_changeset(simulation, attrs) do
    simulation
    |> cast(attrs, [:attempts_count, :duration_seconds])
    |> validate_number(:attempts_count, greater_than_or_equal_to: 0)
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0.0)
  end

  defp validate_completion_timing(changeset) do
    started_at = get_field(changeset, :started_at)
    completed_at = get_field(changeset, :completed_at)

    if started_at && completed_at && DateTime.compare(completed_at, started_at) == :lt do
      add_error(changeset, :completed_at, "must be after or equal to started_at")
    else
      changeset
    end
  end
end
