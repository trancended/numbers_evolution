defmodule NumbersEvolution.Events.Event do
  @moduledoc """
  Event schema for logging user activity and system events.

  Used for analytics, auditing, and rate limiting.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias NumbersEvolution.Accounts.User

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          user_id: Ecto.UUID.t(),
          event_type: String.t(),
          metadata: map() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t()
        }

  @valid_event_types ~w(
    strategy_created
    strategy_updated
    strategy_deleted
    simulation_started
    simulation_completed
    coupons_generated
    strategy_mix_created
    ai_request
    ai_success
    ai_error
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "events" do
    field(:event_type, :string)
    field(:metadata, :map)

    belongs_to(:user, User)

    # Events are immutable - only inserted_at, no updated_at
    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Changeset for creating an event.
  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:user_id, :event_type, :metadata])
    |> validate_required([:user_id, :event_type])
    |> validate_inclusion(:event_type, @valid_event_types)
    |> validate_metadata()
    |> assoc_constraint(:user)
  end

  defp validate_metadata(changeset) do
    case get_change(changeset, :metadata) do
      nil ->
        changeset

      metadata when is_map(metadata) ->
        changeset

      _ ->
        add_error(changeset, :metadata, "must be a valid map")
    end
  end

  @doc """
  Returns list of valid event types.
  """
  def valid_event_types, do: @valid_event_types
end
