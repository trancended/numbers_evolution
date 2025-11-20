defmodule NumbersEvolution.Strategies do
  @moduledoc """
  The Strategies context.

  Handles strategy CRUD operations with user scoping, AI generation,
  and performance tracking.
  """

  import Ecto.Query, warn: false
  alias NumbersEvolution.Accounts.User
  alias NumbersEvolution.Events
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Strategies.Strategy

  ## Queries (always user-scoped)

  @doc """
  Returns the list of strategies for a user.

  ## Options

    * `:type` - Filter by strategy type ("manual" or "ai_generated")
    * `:status` - Filter by status ("active", "deleted", "archived")
    * `:sort` - Field to sort by (default: "inserted_at")
    * `:order` - Sort order ("asc" or "desc", default: "desc")
    * `:page` - Page number for pagination (default: 1)
    * `:per_page` - Items per page (default: 20, max: 100)

  ## Examples

      iex> list_strategies(user)
      [%Strategy{}, ...]

      iex> list_strategies(user, type: "manual", page: 2)
      [%Strategy{}, ...]

  """
  @spec list_strategies(User.t(), keyword()) :: [Strategy.t()]
  def list_strategies(%User{id: user_id}, opts \\ []) do
    from(s in Strategy, where: s.user_id == ^user_id)
    |> apply_filters(opts)
    |> apply_sorting(opts)
    |> paginate(opts)
    |> Repo.all()
  end

  @doc """
  Gets a single strategy for a user.

  Raises `Ecto.NoResultsError` if the Strategy does not exist or doesn't belong to user.

  ## Examples

      iex> get_strategy!(user, "c6a7b042-...")
      %Strategy{}

      iex> get_strategy!(user, "invalid-uuid")
      ** (Ecto.NoResultsError)

  """
  @spec get_strategy!(User.t(), binary()) :: Strategy.t()
  def get_strategy!(%User{id: user_id}, id) do
    from(s in Strategy, where: s.id == ^id and s.user_id == ^user_id)
    |> Repo.one!()
  end

  @doc """
  Gets a strategy with aggregated statistics.
  """
  @spec get_strategy_with_stats(User.t(), binary()) :: Strategy.t()
  def get_strategy_with_stats(user, id) do
    strategy = get_strategy!(user, id)

    simulations_count =
      from(sim in NumbersEvolution.Simulations.Simulation,
        where: sim.strategy_id == ^id,
        select: count(sim.id)
      )
      |> Repo.one()

    Map.put(strategy, :simulations_count, simulations_count)
  end

  @doc """
  Counts strategies for a user with optional filters.
  """
  @spec count_strategies(User.t(), keyword()) :: non_neg_integer()
  def count_strategies(%User{id: user_id}, opts \\ []) do
    from(s in Strategy, where: s.user_id == ^user_id)
    |> apply_filters(opts)
    |> Repo.aggregate(:count)
  end

  ## Creation

  @doc """
  Creates a strategy for a user.

  ## Examples

      iex> create_strategy(user, %{name: "Hot Numbers", type: "manual", rules: %{...}})
      {:ok, %Strategy{}}

      iex> create_strategy(user, %{name: "Invalid"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_strategy(User.t(), map()) ::
          {:ok, Strategy.t()} | {:error, Ecto.Changeset.t()}
  def create_strategy(%User{id: user_id} = user, attrs) do
    result =
      %Strategy{user_id: user_id}
      |> Strategy.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, strategy} ->
        log_strategy_created(user, strategy)
        {:ok, strategy}

      error ->
        error
    end
  end

  @doc """
  Creates an AI-generated strategy for a user based on a text prompt.

  ## Examples

      iex> create_ai_strategy(user, "Pomin połowę liczb (wszystkie parzyste)")
      {:ok, %Strategy{}}

      iex> create_ai_strategy(user, "too short")
      {:error, :invalid_prompt}

  """
  @spec create_ai_strategy(User.t(), String.t()) ::
          {:ok, Strategy.t()} | {:error, atom() | Ecto.Changeset.t()}
  def create_ai_strategy(user, prompt) when is_binary(prompt) do
    # Validate prompt length
    cond do
      String.length(prompt) < 10 ->
        {:error, :prompt_too_short}

      String.length(prompt) > 500 ->
        {:error, :prompt_too_long}

      true ->
        generate_and_create_strategy(user, prompt)
    end
  end

  defp generate_and_create_strategy(user, prompt) do
    case NumbersEvolution.AIProvider.generate_strategy(prompt) do
      {:ok, ai_response} ->
        attrs = %{
          name: ai_response.strategy_name,
          description: ai_response.description,
          type: "ai_generated",
          ai_prompt: prompt,
          rules: ai_response.rules
        }

        create_strategy(user, attrs)

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Updates

  @doc """
  Updates a strategy.

  AI-generated strategies cannot have their rules modified.

  ## Examples

      iex> update_strategy(user, strategy_id, %{name: "New Name"})
      {:ok, %Strategy{}}

      iex> update_strategy(user, strategy_id, %{rules: %{...}})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_strategy(User.t(), binary(), map()) ::
          {:ok, Strategy.t()} | {:error, Ecto.Changeset.t() | :forbidden}
  def update_strategy(user, id, attrs) do
    strategy = get_strategy!(user, id)

    # Check if trying to modify rules of AI-generated strategy
    if strategy.type == "ai_generated" && Map.has_key?(attrs, "rules") do
      {:error, :forbidden}
    else
      strategy
      |> Strategy.update_changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Deletes a strategy (soft delete by setting status to "deleted").

  ## Examples

      iex> delete_strategy(user, strategy_id)
      {:ok, %Strategy{}}

  """
  @spec delete_strategy(User.t(), binary()) :: {:ok, Strategy.t()}
  def delete_strategy(user, id) do
    strategy = get_strategy!(user, id)

    strategy
    |> Ecto.Changeset.change(status: "deleted")
    |> Repo.update()
  end

  ## Private Helpers

  defp apply_filters(query, opts) do
    query
    |> filter_by_type(opts[:type])
    |> filter_by_status(opts[:status])
  end

  defp filter_by_type(query, nil), do: query

  defp filter_by_type(query, type) when type in ["manual", "ai_generated"] do
    from(s in query, where: s.type == ^type)
  end

  defp filter_by_type(query, _), do: query

  defp filter_by_status(query, nil), do: from(s in query, where: s.status == "active")

  defp filter_by_status(query, status) when status in ["active", "deleted", "archived"] do
    from(s in query, where: s.status == ^status)
  end

  defp filter_by_status(query, _), do: query

  defp apply_sorting(query, opts) do
    sort_field = opts[:sort] || "inserted_at"
    sort_order = opts[:order] || "desc"

    field_atom = normalize_sort_field(sort_field)
    order_atom = normalize_sort_order(sort_order)

    from(s in query, order_by: [{^order_atom, ^field_atom}])
  end

  defp normalize_sort_field("name"), do: :name
  defp normalize_sort_field("type"), do: :type
  defp normalize_sort_field("performance_score"), do: :performance_score
  defp normalize_sort_field("inserted_at"), do: :inserted_at
  defp normalize_sort_field("updated_at"), do: :updated_at
  defp normalize_sort_field(_), do: :inserted_at

  defp normalize_sort_order("asc"), do: :asc
  defp normalize_sort_order("desc"), do: :desc
  defp normalize_sort_order(_), do: :desc

  defp paginate(query, opts) do
    page = opts[:page] || 1
    per_page = min(opts[:per_page] || 20, 100)
    offset = (page - 1) * per_page

    from(s in query, limit: ^per_page, offset: ^offset)
  end

  defp log_strategy_created(user, strategy) do
    Events.log_event(user.id, :strategy_created, %{
      entity_type: "strategy",
      entity_id: strategy.id,
      strategy_type: to_string(strategy.type)
    })
  end
end
