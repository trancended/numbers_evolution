defmodule NumbersEvolution.Strategies.Strategy do
  @moduledoc """
  Strategy schema for lottery number generation strategies.

  Supports both manual and AI-generated strategies with dynamic rules stored as JSONB.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias NumbersEvolution.Accounts.User
  alias NumbersEvolution.Simulations.Simulation
  alias NumbersEvolution.Strategies.StrategyRules

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          user_id: Ecto.UUID.t(),
          name: String.t(),
          type: String.t(),
          status: String.t(),
          rules: StrategyRules.t(),
          description: String.t() | nil,
          ai_prompt: String.t() | nil,
          performance_score: float() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          simulations: [Simulation.t()] | Ecto.Association.NotLoaded.t(),
          simulations_count: integer() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @valid_types ~w(manual ai_generated)
  @valid_statuses ~w(active deleted archived)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "strategies" do
    field(:name, :string)
    field(:type, :string)
    field(:status, :string, default: "active")
    field(:description, :string)
    field(:ai_prompt, :string)
    field(:performance_score, :float)
    field(:simulations_count, :integer, virtual: true)

    embeds_one(:rules, StrategyRules)

    belongs_to(:user, User)
    has_many(:simulations, Simulation)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new strategy.
  """
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:name, :type, :status, :description, :ai_prompt, :performance_score])
    |> validate_required([:name, :type])
    |> validate_length(:name, min: 3, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_length(:ai_prompt, max: 1000)
    |> cast_embed(:rules, required: true)
    |> validate_ai_prompt()
    |> assoc_constraint(:user)
  end

  @doc """
  Changeset for updating a strategy.
  AI-generated strategies cannot have their rules modified.
  """
  def update_changeset(strategy, attrs) do
    changeset = changeset(strategy, attrs)

    if strategy.type == "ai_generated" && get_change(changeset, :rules) do
      add_error(
        changeset,
        :rules,
        "AI-generated strategy rules cannot be modified. Create a new strategy instead."
      )
    else
      changeset
    end
  end

  @doc """
  Changeset for updating performance score (internal use).
  """
  def performance_changeset(strategy, performance_score) do
    strategy
    |> change(performance_score: performance_score)
  end

  # Private validators

  defp validate_ai_prompt(changeset) do
    type = get_field(changeset, :type)
    ai_prompt = get_field(changeset, :ai_prompt)

    cond do
      type == "ai_generated" && is_nil(ai_prompt) ->
        add_error(changeset, :ai_prompt, "is required for AI-generated strategies")

      type == "manual" && ai_prompt ->
        put_change(changeset, :ai_prompt, nil)

      true ->
        changeset
    end
  end
end
