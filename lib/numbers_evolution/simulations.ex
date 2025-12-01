defmodule NumbersEvolution.Simulations do
  @moduledoc """
  The Simulations context.

  Handles simulation CRUD, async execution coordination, and progress tracking.
  """

  import Ecto.Query, warn: false
  alias NumbersEvolution.Accounts.User
  alias NumbersEvolution.{AtomicCounter, Draws, Strategies}
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Simulations.{Simulation, SimulationDuplicateController}

  defmodule PrizeTiersTracker do
    @moduledoc """
    ETS-based prize tiers tracker for concurrent prize counting.
    """

    @doc """
    Creates a new ETS table for prize tiers tracking.
    Initializes all 12 tiers with 0 count and empty details list.
    """
    def new do
      table_name = :"prize_tiers_#{:erlang.unique_integer([:positive])}"
      :ets.new(table_name, [:set, :public, :named_table])

      # Initialize all 12 prize tiers with 0 count and empty details
      Enum.each(1..12, fn tier ->
        :ets.insert(table_name, {tier, 0})
        :ets.insert(table_name, {:"#{tier}_details", []})
      end)

      table_name
    end

    @doc """
    Atomically increments the count for a specific prize tier.
    For high tiers (1-5), also stores the matched numbers details.
    """
    def increment_tier(table_name, tier) when tier in 1..12 do
      :ets.update_counter(table_name, tier, 1)
    end

    def increment_tier(table_name, tier, generated, target) when tier in 1..12 do
      :ets.update_counter(table_name, tier, 1)

      # Store details for high prize tiers (1-5)
      if tier in 1..5 do
        details_key = :"#{tier}_details"

        current_details =
          case :ets.lookup(table_name, details_key) do
            [{^details_key, details}] -> details
            [] -> []
          end

        # Calculate matched numbers
        matched_main = count_matches_local(generated.main, target.main_numbers)
        matched_euro = count_matches_local(generated.euro, target.euro_numbers)

        new_detail = %{
          main_matched: matched_main,
          euro_matched: matched_euro,
          main_numbers: generated.main,
          euro_numbers: generated.euro
        }

        :ets.insert(table_name, {details_key, [new_detail | current_details]})
      end
    end

    @doc """
    Gets all prize tiers as a map.
    """
    def get_all(table_name) do
      table_name
      |> :ets.tab2list()
      |> Enum.into(%{})
    end

    @doc """
    Gets prize details for high tiers (1-5) as a map.
    """
    def get_details(table_name) do
      details = %{}

      # Get details for tiers 1-5
      Enum.reduce(1..5, details, fn tier, acc ->
        details_key = :"#{tier}_details"

        tier_details =
          case :ets.lookup(table_name, details_key) do
            [{^details_key, details_list}] -> details_list
            [] -> []
          end

        if tier_details != [] do
          Map.put(acc, tier, tier_details)
        else
          acc
        end
      end)
    end

    @doc """
    Deletes the ETS table to free memory.
    """
    def delete(table_name) do
      :ets.delete(table_name)
    end

    # Local implementation of count_matches for PrizeTiersTracker
    defp count_matches_local(generated_list, target_list) do
      generated_set = MapSet.new(generated_list)
      target_set = MapSet.new(target_list)
      MapSet.intersection(generated_set, target_set) |> MapSet.size()
    end
  end

  defmodule SimulationContext do
    @moduledoc """
    Context struct for simulation execution parameters.
    Reduces function arity by encapsulating related parameters.
    """
    defstruct [
      :strategy,
      :target_numbers,
      :max_attempts,
      :timeout_seconds,
      :start_time,
      :duplicate_controller,
      :current_attempt,
      :simulation_id,
      :half_random_mode,
      :thread_count,
      :counter_table,
      :prize_tiers_table
    ]
  end

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
    query =
      from(s in Simulation, where: s.user_id == ^user_id)
      |> apply_filters(opts)
      |> order_by([s], desc: s.inserted_at)

    query =
      if opts[:limit] do
        from(s in query, limit: ^opts[:limit])
      else
        paginate(query, opts)
      end

    query
    |> preload_strategy()
    |> Repo.all()
  end

  defp preload_strategy(query) do
    from(s in query, preload: [:strategy, :target_draw])
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

  @doc """
  Starts all pending simulations in parallel.

  Each simulation runs in its own independent process, allowing true parallel execution.
  This is called on application startup to resume any pending simulations.

  All simulations are started simultaneously using Task.Supervisor, which manages
  each simulation process independently. There is no limit on the number of
  concurrent simulations.
  """
  @spec start_pending_simulations() :: :ok
  def start_pending_simulations do
    require Logger

    pending_simulations =
      from(s in Simulation,
        where: s.status == "pending",
        preload: [:strategy, :target_draw]
      )
      |> Repo.all()

    Logger.info("Found #{length(pending_simulations)} pending simulations to start")

    # Start all simulations in parallel - each will run in its own process
    Enum.each(pending_simulations, fn simulation ->
      if simulation.strategy && simulation.target_draw do
        Logger.info("Starting pending simulation #{simulation.id} in parallel")
        # Use the same mechanism as create_and_start_simulation
        # Each call to start_simulation_task creates a new independent process
        start_simulation_task_internal(simulation, simulation.strategy, simulation.target_draw)
      else
        Logger.warning("Skipping simulation #{simulation.id} - missing strategy or target_draw")
      end
    end)

    Logger.info("All #{length(pending_simulations)} simulations started in parallel processes")

    :ok
  end

  defp start_simulation_task_internal(simulation, strategy, target_draw) do
    start_simulation_task(simulation, strategy, target_draw)
  end

  ## Creation and Execution

  @doc """
  Creates and starts a new simulation.

  This creates a simulation record and triggers async execution in a separate process.
  Multiple simulations can run in parallel, each in its own independent process.

  ## Examples

      iex> create_and_start_simulation(user, %{
        "strategy_id" => "...",
        "target_draw_id" => "...",
        "max_attempts" => "10000",
        "timeout_seconds" => "86400"
      })
      {:ok, %Simulation{}}

  ## Parallel Execution

  Each simulation runs in its own process managed by Task.Supervisor, allowing
  true parallel execution. There is no limit on the number of concurrent simulations.
  Each process has independent access to the database connection pool.
  """
  @spec create_and_start_simulation(User.t(), map()) ::
          {:ok, Simulation.t()} | {:error, Ecto.Changeset.t() | atom()}
  def create_and_start_simulation(%User{id: user_id} = user, attrs) do
    with {:ok, strategy} <- validate_strategy(user, attrs["strategy_id"]),
         {:ok, target_draw} <- validate_draw(attrs["target_draw_id"]),
         {:ok, simulation} <- create_simulation_record(user_id, attrs) do
      # Start async execution
      start_simulation_task(simulation, strategy, target_draw)
      {:ok, simulation}
    end
  end

  @doc """
  Starts a new simulation (legacy function, redirects to create_and_start_simulation).

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
  def start_simulation(user, attrs) do
    create_and_start_simulation(user, attrs)
  end

  @doc """
  Cleans up orphaned simulations that are marked as "running" but have no active processes.

  This should be called on application startup to handle server restarts where
  background simulation processes were lost but database still shows them as running.

  ## Examples

      iex> cleanup_orphaned_simulations()
      :ok

  """
  @spec cleanup_orphaned_simulations() :: :ok
  def cleanup_orphaned_simulations do
    require Logger

    # Mark all "running" simulations as "cancelled" since we can't resume them after restart
    {count, _} =
      Repo.update_all(
        from(s in Simulation, where: s.status == "running"),
        set: [status: "cancelled", updated_at: DateTime.utc_now()]
      )

    if count > 0 do
      Logger.info("Marked #{count} orphaned running simulations as cancelled")
    end

    :ok
  end

  @doc """
  Retries a failed simulation by creating a new one with the same parameters.

  ## Examples

      iex> retry_simulation(user, "simulation-id")
      {:ok, %Simulation{}}

      iex> retry_simulation(user, "invalid-id")
      {:error, :not_found}

  """
  @spec retry_simulation(User.t(), binary()) ::
          {:ok, Simulation.t()} | {:error, Ecto.Changeset.t() | atom()}
  def retry_simulation(user, simulation_id) do
    case get_simulation_with_details(user, simulation_id) do
      %Simulation{
        status: status,
        strategy_id: strategy_id,
        target_draw_id: target_draw_id,
        options: options
      }
      when status in ["error", "timeout", "max_attempts_reached", "success", "cancelled"] ->
        attrs = %{
          "strategy_id" => strategy_id,
          "target_draw_id" => target_draw_id,
          "max_attempts" => get_in(options, ["max_attempts"]) || "999999999",
          "timeout_seconds" => get_in(options, ["timeout_seconds"]) || "86400"
        }

        create_and_start_simulation(user, attrs)

      %Simulation{status: status} when status in ["pending", "running"] ->
        {:error, :not_retryable}

      _ ->
        {:error, :not_found}
    end
  rescue
    Ecto.NoResultsError ->
      {:error, :not_found}
  end

  @doc """
  Updates max attempts limit for a simulation and retries it.

  ## Examples

      iex> update_max_attempts_and_retry(user, "simulation-id", "2000000")
      {:ok, %Simulation{}}

  """
  @spec update_max_attempts_and_retry(User.t(), binary(), String.t() | integer()) ::
          {:ok, Simulation.t()} | {:error, Ecto.Changeset.t() | atom()}
  def update_max_attempts_and_retry(user, simulation_id, new_max_attempts) do
    case get_simulation_with_details(user, simulation_id) do
      %Simulation{
        status: "max_attempts_reached",
        strategy_id: strategy_id,
        target_draw_id: target_draw_id,
        options: options
      } ->
        max_attempts_str =
          if is_integer(new_max_attempts) do
            Integer.to_string(new_max_attempts)
          else
            new_max_attempts
          end

        attrs = %{
          "strategy_id" => strategy_id,
          "target_draw_id" => target_draw_id,
          "max_attempts" => max_attempts_str,
          "timeout_seconds" => get_in(options, ["timeout_seconds"]) || "86400"
        }

        create_and_start_simulation(user, attrs)

      %Simulation{status: status} when status != "max_attempts_reached" ->
        {:error, :not_retryable}

      _ ->
        {:error, :not_found}
    end
  rescue
    Ecto.NoResultsError ->
      {:error, :not_found}
  end

  @doc """
  Updates timeout limit for a simulation and retries it.

  ## Examples

      iex> update_timeout_and_retry(user, "simulation-id", "600")
      {:ok, %Simulation{}}

  """
  @spec update_timeout_and_retry(User.t(), binary(), String.t() | integer()) ::
          {:ok, Simulation.t()} | {:error, Ecto.Changeset.t() | atom()}
  def update_timeout_and_retry(user, simulation_id, new_timeout_seconds) do
    case get_simulation_with_details(user, simulation_id) do
      %Simulation{
        status: "timeout",
        strategy_id: strategy_id,
        target_draw_id: target_draw_id,
        options: options
      } ->
        timeout_str =
          if is_integer(new_timeout_seconds) do
            Integer.to_string(new_timeout_seconds)
          else
            new_timeout_seconds
          end

        attrs = %{
          "strategy_id" => strategy_id,
          "target_draw_id" => target_draw_id,
          "max_attempts" => get_in(options, ["max_attempts"]) || "999999999",
          "timeout_seconds" => timeout_str
        }

        create_and_start_simulation(user, attrs)

      %Simulation{status: status} when status != "timeout" ->
        {:error, :not_retryable}

      _ ->
        {:error, :not_found}
    end
  rescue
    Ecto.NoResultsError ->
      {:error, :not_found}
  end

  @doc """
  Updates options for an existing simulation and resets its status to allow restarting.

  This allows updating parameters of an existing simulation without creating a new record.
  The simulation status is reset to "pending" and progress counters are cleared.

  ## Examples

      iex> update_simulation_options(user, "simulation-id", %{"max_attempts" => "2000000"})
      {:ok, %Simulation{}}

      iex> update_simulation_options(user, "invalid-id", %{})
      {:error, :not_found}

  """
  @spec update_simulation_options(User.t(), binary(), map()) ::
          {:ok, Simulation.t()} | {:error, Ecto.Changeset.t() | atom()}
  def update_simulation_options(%User{id: _user_id} = user, simulation_id, new_options) do
    with {:ok, simulation} <- get_simulation_with_details(user, simulation_id) do
      # Validate that simulation can be restarted
      if simulation.status in [
           "pending",
           "success",
           "error",
           "timeout",
           "max_attempts_reached",
           "cancelled"
         ] do
        parsed_options = parse_options(new_options)

        # Merge new options with existing ones
        existing_options = simulation.options || %{}
        updated_options = Map.merge(existing_options, parsed_options)

        simulation
        |> Simulation.changeset(%{options: updated_options})
        |> Ecto.Changeset.change(%{
          status: "pending",
          attempts_count: 0,
          duration_seconds: 0.0,
          started_at: nil,
          completed_at: nil
        })
        |> Repo.update()
      else
        {:error, :simulation_running}
      end
    end
  rescue
    Ecto.NoResultsError ->
      {:error, :not_found}
  end

  @doc """
  Restarts an existing simulation with updated options.

  This updates the simulation options and immediately starts the simulation process.
  Equivalent to calling update_simulation_options followed by starting the simulation.

  ## Examples

      iex> restart_simulation(user, "simulation-id", %{"max_attempts" => "2000000"})
      {:ok, %Simulation{}}

      iex> restart_simulation(user, "running-simulation", %{})
      {:error, :simulation_running}

  """
  @spec restart_simulation(User.t(), binary(), map()) ::
          {:ok, Simulation.t()} | {:error, Ecto.Changeset.t() | atom()}
  def restart_simulation(%User{id: _user_id} = user, simulation_id, new_options \\ %{}) do
    with {:ok, updated_simulation} <- update_simulation_options(user, simulation_id, new_options),
         {:ok, simulation_with_details} <- get_simulation_with_details(user, simulation_id) do
      # Start the simulation process
      start_simulation_task(
        simulation_with_details,
        simulation_with_details.strategy,
        simulation_with_details.target_draw
      )

      {:ok, updated_simulation}
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
    options = parse_options(attrs)

    %Simulation{user_id: user_id}
    |> Simulation.changeset(%{
      strategy_id: attrs["strategy_id"],
      target_draw_id: attrs["target_draw_id"],
      status: "pending",
      options: options
    })
    |> Repo.insert()
  end

  defp parse_options(attrs) do
    max_attempts = parse_int(attrs["max_attempts"], 1_000_000)
    timeout_seconds = parse_int(attrs["timeout_seconds"], 86_400)
    half_random_mode = parse_boolean(attrs["half_random_mode"], false)
    thread_count = parse_int(attrs["thread_count"], 10)

    %{
      "max_attempts" => max_attempts,
      "timeout_seconds" => timeout_seconds,
      "half_random_mode" => half_random_mode,
      "thread_count" => thread_count
    }
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_int(value, _default) when is_integer(value), do: value
  defp parse_int(_, default), do: default

  defp parse_boolean(nil, default), do: default
  defp parse_boolean("", default), do: default
  defp parse_boolean(value, _default) when is_boolean(value), do: value
  defp parse_boolean("true", _default), do: true
  defp parse_boolean("false", _default), do: false
  defp parse_boolean(_, default), do: default

  defp start_simulation_task(simulation, strategy, target_draw) do
    require Logger

    Logger.info(
      "Starting simulation task for simulation #{simulation.id} (process: #{inspect(self())})"
    )

    # Use Task.Supervisor to ensure proper process supervision and Repo access
    # Each simulation runs in its own independent process, allowing parallel execution
    case Task.Supervisor.start_child(
           NumbersEvolution.TaskSupervisor,
           fn ->
             process_id = inspect(self())
             Logger.info("Simulation #{simulation.id} running in process #{process_id}")

             try do
               run_simulation(simulation.id, strategy, target_draw)
             catch
               kind, error ->
                 Logger.error("Simulation task crashed: #{inspect({kind, error})}")
                 Logger.error(Exception.format(kind, error, __STACKTRACE__))
             end
           end
         ) do
      {:ok, task_pid} ->
        Logger.info(
          "Simulation task started successfully for #{simulation.id} in process #{inspect(task_pid)}"
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to start simulation task for #{simulation.id}: #{inspect(reason)}")
        # Update simulation status to error
        try do
          simulation = Repo.get!(Simulation, simulation.id)

          simulation
          |> Simulation.completion_changeset("error", %{
            attempts_count: 0,
            duration_seconds: 0.0
          })
          |> Ecto.Changeset.put_embed(:result, %{
            error_message: "Failed to start task: #{inspect(reason)}"
          })
          |> Repo.update()
        rescue
          _ -> :ok
        end

        :error
    end
  end

  defp run_simulation(simulation_id, strategy, target_draw) do
    require Logger
    process_id = inspect(self())
    Logger.info("Running simulation #{simulation_id} in process #{process_id}")

    try do
      Logger.info("Starting simulation #{simulation_id} (process: #{process_id})")

      # Load simulation with fresh data
      # Each simulation process has its own database connection pool access
      simulation = Repo.get!(Simulation, simulation_id)

      # Update status to running
      updated_simulation =
        simulation
        |> Simulation.start_changeset()
        |> Repo.update!()

      Logger.info("Simulation #{simulation_id} status updated to running")

      # Get options from updated simulation
      options = updated_simulation.options || %{}
      max_attempts = Map.get(options, "max_attempts", 1_000_000)
      timeout_seconds = Map.get(options, "timeout_seconds", 86_400)

      start_time = System.monotonic_time(:second)

      # Inicjalizuj kontroler duplikatów
      duplicate_controller = SimulationDuplicateController.new()

      # Inicjalizuj atomiczny licznik ETS (znacznie szybszy niż GenServer)
      counter_table = AtomicCounter.new(0)

      # Inicjalizuj tracker nagród
      prize_tiers_table = PrizeTiersTracker.new()

      # Run simulation loop
      half_random_mode = Map.get(options, "half_random_mode", false)
      thread_count = Map.get(options, "thread_count", 48)

      context = %SimulationContext{
        strategy: strategy,
        target_numbers: target_draw.numbers,
        max_attempts: max_attempts,
        timeout_seconds: timeout_seconds,
        start_time: start_time,
        duplicate_controller: duplicate_controller,
        current_attempt: 0,
        simulation_id: simulation_id,
        half_random_mode: half_random_mode,
        thread_count: thread_count,
        counter_table: counter_table,
        prize_tiers_table: prize_tiers_table
      }

      result = simulate_until_match(context)

      # Finalize simulation
      finalize_simulation(
        simulation_id,
        result,
        start_time,
        strategy,
        duplicate_controller,
        prize_tiers_table
      )
    rescue
      e ->
        Logger.error("Simulation #{simulation_id} crashed: #{inspect(e)}")
        Logger.error(Exception.format(:error, e, __STACKTRACE__))

        try do
          simulation = Repo.get!(Simulation, simulation_id)

          simulation
          |> Simulation.completion_changeset("error", %{
            attempts_count: 0,
            duration_seconds: 0.0
          })
          |> Ecto.Changeset.put_embed(:result, %{
            reason: "error",
            limit_reached: "error",
            error_message: Exception.message(e)
          })
          |> Repo.update!()
        rescue
          _ -> :ok
        end
    end
  end

  defp simulate_until_match(%SimulationContext{} = context) do
    # Check limits first - use atomic counter for attempt count
    current_count = AtomicCounter.get(context.counter_table)

    case check_simulation_limits(
           current_count,
           context.max_attempts,
           context.start_time,
           context.timeout_seconds
         ) do
      {:continue, _} ->
        process_simulation_attempts_parallel(context)

      {:timeout, reason} ->
        {:timeout, reason, current_count, context.duplicate_controller}
    end
  end

  defp process_simulation_attempts_parallel(%SimulationContext{} = context) do
    # Uruchom wiele wątków równolegle do generowania prób
    tasks =
      Enum.map(1..context.thread_count, fn _thread_id ->
        Task.async(fn ->
          generate_and_check_attempt(context)
        end)
      end)

    # Poczekaj na pierwsze zakończenie zadania (pierwsze które znajdzie dopasowanie lub przetworzy próbę)
    case Task.yield_many(tasks, 5000) do
      [{_task, {:match_found, generated, updated_controller}} | _rest] ->
        # Znaleziono dopasowanie - anuluj pozostałe zadania
        Enum.each(tasks, &Task.shutdown/1)
        {:success, AtomicCounter.get(context.counter_table), generated, updated_controller}

      [] ->
        # Brak zakończonych zadań w czasie - spróbuj ponownie
        process_simulation_attempts_parallel(context)

      _results ->
        # Wszystkie zadania zakończone ale bez dopasowania - kontynuuj
        simulate_until_match(context)
    end
  end

  defp generate_and_check_attempt(context) do
    case Strategies.Generator.generate_numbers(context.strategy,
           half_random_mode: context.half_random_mode
         ) do
      {:ok, generated} ->
        handle_generated_numbers(context, generated)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_generated_numbers(context, generated) do
    case SimulationDuplicateController.check_attempt(context.duplicate_controller, generated) do
      {:duplicate, updated_controller} ->
        handle_duplicate_attempt(context, updated_controller)

      {:unique, updated_controller} ->
        handle_unique_attempt(context, generated, updated_controller)
    end
  end

  defp handle_duplicate_attempt(context, updated_controller) do
    # Duplikat - zwiększ licznik atomicznie (bez kolejki!)
    new_count = AtomicCounter.increment(context.counter_table)
    # Broadcastuj tylko co 100 prób dla wydajności
    maybe_broadcast_progress(
      new_count,
      context.simulation_id,
      context.start_time,
      context.prize_tiers_table
    )

    {:duplicate, updated_controller}
  end

  defp handle_unique_attempt(context, generated, updated_controller) do
    # Unikalna próba - zwiększ licznik atomicznie
    new_count = AtomicCounter.increment(context.counter_table)
    # Broadcastuj tylko co 100 prób dla wydajności
    maybe_broadcast_progress(
      new_count,
      context.simulation_id,
      context.start_time,
      context.prize_tiers_table
    )

    # Sprawdź wszystkie możliwe stopnie nagród i zlicz je
    all_tiers = calculate_all_prize_tiers(generated, context.target_numbers)

    # Zlicz wszystkie trafione tier'y
    Enum.each(all_tiers, fn tier ->
      PrizeTiersTracker.increment_tier(
        context.prize_tiers_table,
        tier,
        generated,
        context.target_numbers
      )
    end)

    # Sprawdź czy jest jackpot (tier 1)
    if 1 in all_tiers do
      {:match_found, generated, updated_controller}
    else
      {:unique_no_match, updated_controller}
    end
  end

  defp maybe_broadcast_progress(count, simulation_id, start_time, prize_tiers_table) do
    if rem(count, 100) == 0 do
      prize_tiers = PrizeTiersTracker.get_all(prize_tiers_table)
      broadcast_progress(simulation_id, count, start_time, prize_tiers)
    end
  end

  defp check_simulation_limits(current_attempt, max_attempts, start_time, timeout_seconds) do
    cond do
      current_attempt >= max_attempts ->
        {:timeout, "max_attempts"}

      System.monotonic_time(:second) - start_time >= timeout_seconds ->
        {:timeout, "time_limit"}

      true ->
        {:continue, nil}
    end
  end

  @prize_tiers %{
    # I (5+2)
    {5, 2} => 1,
    # II (5+1)
    {5, 1} => 2,
    # III (5+0)
    {5, 0} => 3,
    # IV (4+2)
    {4, 2} => 4,
    # V (4+1)
    {4, 1} => 5,
    # VI (3+2)
    {3, 2} => 6,
    # VII (4+0)
    {4, 0} => 7,
    # VIII (2+2)
    {2, 2} => 8,
    # IX (3+1)
    {3, 1} => 9,
    # X (3+0)
    {3, 0} => 10,
    # XI (1+2)
    {1, 2} => 11,
    # XII (2+1)
    {2, 1} => 12
  }

  # Calculates all prize tiers that match for a given draw.
  # For example, if someone matches 5+2, they also technically match 5+1, 5+0, 4+2, 4+1, etc.
  # Returns a list of all matching tier numbers.
  defp calculate_all_prize_tiers(generated, target_numbers) do
    main_matches = count_matches(generated.main, target_numbers.main_numbers)
    euro_matches = count_matches(generated.euro, target_numbers.euro_numbers)

    # Generate all possible combinations from current matches down to minimum winning combinations
    # Note: euro can be 0 (prizes exist for X+0 combinations)
    for main <- 1..main_matches,
        euro <- 0..euro_matches,
        tier = Map.get(@prize_tiers, {main, euro}),
        tier != nil do
      tier
    end
    |> Enum.sort()
  end

  defp count_matches(generated_list, target_list) do
    generated_set = MapSet.new(generated_list)
    target_set = MapSet.new(target_list)
    MapSet.intersection(generated_set, target_set) |> MapSet.size()
  end

  defp broadcast_progress(simulation_id, attempts, start_time, prize_tiers) do
    duration = System.monotonic_time(:second) - start_time

    Phoenix.PubSub.broadcast(
      NumbersEvolution.PubSub,
      "simulation:#{simulation_id}",
      {:simulation_progress, simulation_id,
       %{
         attempts: attempts,
         duration_seconds: duration,
         prize_tiers: prize_tiers
       }}
    )
  end

  defp finalize_simulation(
         simulation_id,
         result,
         start_time,
         strategy,
         duplicate_controller,
         prize_tiers_table
       ) do
    simulation = Repo.get!(Simulation, simulation_id)
    duration = System.monotonic_time(:second) - start_time

    # Pobierz statystyki duplikatów
    duplicate_stats = SimulationDuplicateController.get_stats(duplicate_controller)

    # Pobierz statystyki nagród
    prize_tiers = PrizeTiersTracker.get_all(prize_tiers_table)
    prize_details = PrizeTiersTracker.get_details(prize_tiers_table)

    case result do
      {:success, attempts, matched_numbers, _controller} ->
        result_data = %{
          matched_main: matched_numbers.main,
          matched_euro: matched_numbers.euro,
          attempts_count: attempts,
          duplicates_skipped: duplicate_stats.duplicates_skipped,
          unique_attempts: attempts,
          prize_tiers: prize_tiers,
          prize_details: prize_details,
          final_draw: %{
            main_numbers: matched_numbers.main,
            euro_numbers: matched_numbers.euro
          }
        }

        simulation
        |> Simulation.completion_changeset("success", %{
          attempts_count: attempts,
          duration_seconds: duration
        })
        |> Ecto.Changeset.put_embed(:result, result_data)
        |> Repo.update!()

        # Update strategy performance score
        update_strategy_performance(strategy.id)

      {:timeout, reason, attempts, _controller} ->
        status = if reason == "max_attempts", do: "max_attempts_reached", else: "timeout"

        result_data = %{
          reason: "timeout",
          limit_reached: reason,
          attempts_count: attempts,
          duplicates_skipped: duplicate_stats.duplicates_skipped,
          unique_attempts: attempts,
          prize_tiers: prize_tiers,
          prize_details: prize_details
        }

        simulation
        |> Simulation.completion_changeset(status, %{
          attempts_count: attempts,
          duration_seconds: duration
        })
        |> Ecto.Changeset.put_embed(:result, result_data)
        |> Repo.update!()

      {:error, reason} ->
        result_data = %{
          reason: "error",
          limit_reached: "error",
          error_message: inspect(reason),
          duplicates_skipped: duplicate_stats.duplicates_skipped,
          unique_attempts: 0,
          prize_tiers: prize_tiers,
          prize_details: prize_details
        }

        simulation
        |> Simulation.completion_changeset("error", %{
          duration_seconds: duration
        })
        |> Ecto.Changeset.put_embed(:result, result_data)
        |> Repo.update!()
    end

    # Broadcast completion
    Phoenix.PubSub.broadcast(
      NumbersEvolution.PubSub,
      "simulation:#{simulation_id}",
      {:simulation_complete, simulation}
    )
  end

  defp update_strategy_performance(strategy_id) do
    # Calculate median attempts from successful simulations
    successful_simulations =
      from(s in Simulation,
        where: s.strategy_id == ^strategy_id and s.status == "success",
        select: s.attempts_count,
        order_by: [asc: s.attempts_count]
      )
      |> Repo.all()

    if length(successful_simulations) > 0 do
      median = calculate_median(successful_simulations)

      strategy = Repo.get!(Strategies.Strategy, strategy_id)

      strategy
      |> Strategies.Strategy.performance_changeset(median)
      |> Repo.update!()
    end
  end

  defp calculate_median(sorted_list) when is_list(sorted_list) do
    count = length(sorted_list)

    if rem(count, 2) == 0 do
      # Even number of elements - average of two middle values
      mid1 = Enum.at(sorted_list, div(count, 2) - 1)
      mid2 = Enum.at(sorted_list, div(count, 2))
      (mid1 + mid2) / 2.0
    else
      # Odd number of elements - middle value
      Enum.at(sorted_list, div(count, 2))
    end
  end

  defp apply_filters(query, opts) do
    query
    |> filter_by_status(opts[:status])
    |> filter_by_strategy(opts[:strategy_id])
  end

  defp filter_by_status(query, nil), do: query

  defp filter_by_status(query, status) when is_binary(status) do
    from(s in query, where: s.status == ^status)
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

  @doc """
  Deletes a simulation for a user.

  ## Examples

      iex> delete_simulation(user, "simulation-id")
      {:ok, %Simulation{}}

      iex> delete_simulation(user, "invalid-id")
      {:error, :not_found}

  """
  @spec delete_simulation(User.t(), binary()) ::
          {:ok, Simulation.t()} | {:error, atom() | Ecto.Changeset.t()}
  def delete_simulation(user, simulation_id) do
    simulation = get_simulation!(user, simulation_id)

    case Repo.delete(simulation) do
      {:ok, deleted_simulation} ->
        {:ok, deleted_simulation}

      {:error, changeset} ->
        {:error, changeset}
    end
  rescue
    Ecto.NoResultsError ->
      {:error, :not_found}

    Ecto.StaleEntryError ->
      {:error, :stale_entry}

    error ->
      require Logger
      Logger.error("Unexpected error deleting simulation: #{inspect(error)}")
      {:error, :unknown_error}
  end

  @doc """
  Stops a running simulation by setting its status to "cancelled".

  This immediately terminates the simulation process and updates the database.
  Only works for simulations with status "running".

  ## Examples

      iex> stop_simulation(user, "simulation-id")
      {:ok, %Simulation{}}

      iex> stop_simulation(user, "not-running-simulation")
      {:error, :not_running}

  """
  @spec stop_simulation(User.t(), binary()) :: {:ok, Simulation.t()} | {:error, atom()}
  def stop_simulation(%User{id: _user_id} = user, simulation_id) do
    with {:ok, simulation} <- get_simulation_with_details(user, simulation_id) do
      if simulation.status == "running" do
        simulation
        |> Simulation.completion_changeset("cancelled", %{
          attempts_count: simulation.attempts_count,
          duration_seconds: simulation.duration_seconds
        })
        |> Repo.update()
      else
        {:error, :not_running}
      end
    end
  rescue
    Ecto.NoResultsError ->
      {:error, :not_found}
  end

  @doc """
  Resumes a cancelled simulation by changing its status back to "pending" and starting it.

  This allows continuing a previously stopped simulation with its existing parameters.
  Only works for simulations with status "cancelled".

  ## Examples

      iex> resume_simulation(user, "simulation-id")
      {:ok, %Simulation{}}

      iex> resume_simulation(user, "not-cancelled-simulation")
      {:error, :not_cancelled}

  """
  @spec resume_simulation(User.t(), binary()) :: {:ok, Simulation.t()} | {:error, atom()}
  def resume_simulation(%User{id: _user_id} = user, simulation_id) do
    with {:ok, simulation} <- get_simulation_with_details(user, simulation_id) do
      if simulation.status == "cancelled" do
        # Reset simulation to pending state
        simulation
        |> Ecto.Changeset.change(%{
          status: "pending",
          started_at: nil,
          completed_at: nil
        })
        |> Repo.update()
        |> case do
          {:ok, updated_simulation} ->
            # Start the simulation process
            start_simulation_task(
              updated_simulation,
              updated_simulation.strategy,
              updated_simulation.target_draw
            )

            {:ok, updated_simulation}
        end
      else
        {:error, :not_cancelled}
      end
    end
  rescue
    Ecto.NoResultsError ->
      {:error, :not_found}
  end

  @doc """
  Toggles the favorite status of a simulation.

  ## Examples

      iex> toggle_favorite(user, "simulation-id")
      {:ok, %Simulation{is_favorite: true}}

  """
  @spec toggle_favorite(User.t(), binary()) :: {:ok, Simulation.t()} | {:error, atom()}
  def toggle_favorite(user, simulation_id) do
    simulation = get_simulation!(user, simulation_id)
    new_favorite_status = !simulation.is_favorite

    simulation
    |> Ecto.Changeset.change(is_favorite: new_favorite_status)
    |> Repo.update()
  rescue
    Ecto.NoResultsError ->
      {:error, :not_found}
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
