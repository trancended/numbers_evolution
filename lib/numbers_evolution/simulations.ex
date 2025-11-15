defmodule NumbersEvolution.Simulations do
  @moduledoc """
  The Simulations context.

  Handles simulation CRUD, async execution coordination, and progress tracking.
  """

  import Ecto.Query, warn: false
  alias NumbersEvolution.Accounts.User
  alias NumbersEvolution.{Draws, Strategies}
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Simulations.Simulation

  ## Queries

  @doc """
  Returns the list of simulations for a user.

  ## Options

    * `:status` - Filter by status
    * `:strategy_id` - Filter by strategy
    * `:page` - Page number for pagination (default: 1)
    * `:per_page` - Items per page (default: 20, max: 100)

  ## Examples

      iex> list_simulations(user)
      [%Simulation{}, ...]

      iex> list_simulations(user, status: "success", page: 2)
      [%Simulation{}, ...]

  """
  @spec list_simulations(User.t(), keyword()) :: [Simulation.t()]
  def list_simulations(%User{id: user_id}, opts \\ []) do
    from(s in Simulation, where: s.user_id == ^user_id)
    |> apply_filters(opts)
    |> order_by([s], desc: s.inserted_at)
    |> paginate(opts)
    |> Repo.all()
  end

  @doc """
  Gets a single simulation for a user.

  Raises `Ecto.NoResultsError` if the Simulation does not exist or doesn't belong to user.

  ## Examples

      iex> get_simulation!(user, "c6a7b042-...")
      %Simulation{}

      iex> get_simulation!(user, "invalid-uuid")
      ** (Ecto.NoResultsError)

  """
  @spec get_simulation!(User.t(), binary()) :: Simulation.t()
  def get_simulation!(%User{id: user_id}, id) do
    from(s in Simulation, where: s.id == ^id and s.user_id == ^user_id)
    |> Repo.one!()
  end

  @doc """
  Gets a simulation with preloaded strategy and target_draw.

  ## Examples

      iex> get_simulation_with_details(user, simulation_id)
      %Simulation{strategy: %Strategy{}, target_draw: %Draw{}}

  """
  @spec get_simulation_with_details(User.t(), binary()) :: Simulation.t()
  def get_simulation_with_details(user, id) do
    get_simulation!(user, id)
    |> Repo.preload([:strategy, :target_draw])
  end

  @doc """
  Counts simulations for a user with optional filters.
  """
  @spec count_simulations(User.t(), keyword()) :: non_neg_integer()
  def count_simulations(%User{id: user_id}, opts \\ []) do
    from(s in Simulation, where: s.user_id == ^user_id)
    |> apply_filters(opts)
    |> Repo.aggregate(:count)
  end

  ## Creation and Execution

  @doc """
  Starts a new simulation.

  This creates a simulation record and triggers async execution.

  ## Examples

      iex> start_simulation(user, %{
        "strategy_id" => "...",
        "target_draw_id" => "...",
        "options" => %{"max_attempts" => 10000}
      })
      {:ok, %Simulation{}}

  """
  @spec start_simulation(User.t(), map()) ::
          {:ok, Simulation.t()} | {:error, Ecto.Changeset.t() | atom()}
  def start_simulation(%User{id: user_id} = user, attrs) do
    # Start async execution (will be implemented in Runner module)
    # For now, we just return the pending simulation
    with {:ok, _strategy} <- validate_strategy(user, attrs["strategy_id"]),
         {:ok, _draw} <- validate_draw(attrs["target_draw_id"]) do
      create_simulation_record(user_id, attrs)
    end
  end

  @doc """
  Completes a simulation with the given status and result data.

  This is called by the simulation runner when execution finishes.

  ## Examples

      iex> complete_simulation(simulation_id, :success, %{
        attempts_count: 5000,
        duration_seconds: 2.5,
        result: %{matched_main: [...], matched_euro: [...]}
      })
      {:ok, %Simulation{}}

  """
  @spec complete_simulation(binary(), atom(), map()) :: {:ok, Simulation.t()}
  def complete_simulation(simulation_id, status, result_data) do
    simulation = Repo.get!(Simulation, simulation_id)

    {:ok, updated} =
      Repo.transaction(fn ->
        simulation
        |> Simulation.completion_changeset(status, result_data)
        |> Repo.update!()
        |> handle_simulation_completion(simulation_id)
      end)

    {:ok, updated}
  end

  @doc """
  Gets the current progress of a simulation.

  ## Examples

      iex> get_simulation_progress(user, simulation_id)
      %{
        id: "...",
        status: :running,
        attempts_count: 5000,
        duration_seconds: 2.5,
        started_at: ~U[...]
      }

  """
  @spec get_simulation_progress(User.t(), binary()) :: map()
  def get_simulation_progress(user, id) do
    simulation = get_simulation!(user, id)

    %{
      id: simulation.id,
      status: simulation.status,
      attempts_count: simulation.attempts_count,
      duration_seconds: simulation.duration_seconds,
      started_at: simulation.started_at
    }
  end

  ## Private Helpers

  defp validate_strategy(user, strategy_id) when is_binary(strategy_id) do
    strategy = Strategies.get_strategy!(user, strategy_id)
    {:ok, strategy}
  rescue
    Ecto.NoResultsError -> {:error, :strategy_not_found}
  end

  defp validate_strategy(_user, _), do: {:error, :invalid_strategy_id}

  defp validate_draw(draw_id) when is_binary(draw_id) do
    draw = Draws.get_draw!(draw_id)
    {:ok, draw}
  rescue
    Ecto.NoResultsError -> {:error, :draw_not_found}
  end

  defp validate_draw(_), do: {:error, :invalid_draw_id}

  defp create_simulation_record(user_id, attrs) do
    %Simulation{user_id: user_id}
    |> Simulation.changeset(%{
      strategy_id: attrs["strategy_id"],
      target_draw_id: attrs["target_draw_id"],
      status: :pending,
      started_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp apply_filters(query, opts) do
    query
    |> filter_by_status(opts[:status])
    |> filter_by_strategy(opts[:strategy_id])
  end

  defp filter_by_status(query, nil), do: query

  defp filter_by_status(query, status) when is_binary(status) do
    status_atom = String.to_existing_atom(status)
    from(s in query, where: s.status == ^status_atom)
  rescue
    ArgumentError -> query
  end

  defp filter_by_status(query, _), do: query

  defp filter_by_strategy(query, nil), do: query

  defp filter_by_strategy(query, strategy_id) when is_binary(strategy_id) do
    from(s in query, where: s.strategy_id == ^strategy_id)
  end

  defp filter_by_strategy(query, _), do: query

  defp paginate(query, opts) do
    page = opts[:page] || 1
    per_page = min(opts[:per_page] || 20, 100)
    offset = (page - 1) * per_page

    from(s in query, limit: ^per_page, offset: ^offset)
  end

  defp handle_simulation_completion(sim, simulation_id) do
    # Trigger performance recalculation if strategy exists
    if sim.strategy_id do
      # This will be implemented in PerformanceCalculator
      :ok
    end

    # Broadcast completion via PubSub
    Phoenix.PubSub.broadcast(
      NumbersEvolution.PubSub,
      "simulation:#{simulation_id}",
      {:simulation_complete, sim}
    )

    sim
  end
end
