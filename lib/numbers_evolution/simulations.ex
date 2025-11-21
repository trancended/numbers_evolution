defmodule NumbersEvolution.Simulations do
  @moduledoc """
  The Simulations context.

  Handles simulation CRUD, async execution coordination, and progress tracking.
  """

  import Ecto.Query, warn: false
  alias NumbersEvolution.Accounts.User
  alias NumbersEvolution.{Draws, Strategies}
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Simulations.{Simulation, SimulationDuplicateController}

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

    %{
      "max_attempts" => max_attempts,
      "timeout_seconds" => timeout_seconds,
      "half_random_mode" => half_random_mode
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

      # Run simulation loop
      half_random_mode = Map.get(options, "half_random_mode", false)

      result =
        simulate_until_match(
          strategy,
          target_draw.numbers,
          max_attempts,
          timeout_seconds,
          start_time,
          duplicate_controller,
          0,
          simulation_id,
          half_random_mode
        )

      # Finalize simulation
      finalize_simulation(simulation_id, result, start_time, strategy, duplicate_controller)
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

  defp simulate_until_match(
         strategy,
         target_numbers,
         max_attempts,
         timeout_seconds,
         start_time,
         duplicate_controller,
         current_attempt,
         simulation_id,
         half_random_mode
       ) do
    # Check limits first
    case check_simulation_limits(current_attempt, max_attempts, start_time, timeout_seconds) do
      {:continue, _} ->
        process_simulation_attempt(
          strategy,
          target_numbers,
          max_attempts,
          timeout_seconds,
          start_time,
          duplicate_controller,
          current_attempt,
          simulation_id,
          half_random_mode
        )

      {:timeout, reason} ->
        {:timeout, reason, current_attempt, duplicate_controller}
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

  defp process_simulation_attempt(
         strategy,
         target_numbers,
         max_attempts,
         timeout_seconds,
         start_time,
         duplicate_controller,
         current_attempt,
         simulation_id,
         half_random_mode
       ) do
    case NumbersEvolution.Strategies.Generator.generate_numbers(strategy,
           half_random_mode: half_random_mode
         ) do
      {:ok, generated} ->
        handle_generated_numbers(
          generated,
          strategy,
          target_numbers,
          max_attempts,
          timeout_seconds,
          start_time,
          duplicate_controller,
          current_attempt,
          simulation_id,
          half_random_mode
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_generated_numbers(
         generated,
         strategy,
         target_numbers,
         max_attempts,
         timeout_seconds,
         start_time,
         duplicate_controller,
         current_attempt,
         simulation_id,
         half_random_mode
       ) do
    case SimulationDuplicateController.check_attempt(duplicate_controller, generated) do
      {:duplicate, updated_controller} ->
        # Skip duplicate - recursive call without incrementing attempt counter
        simulate_until_match(
          strategy,
          target_numbers,
          max_attempts,
          timeout_seconds,
          start_time,
          updated_controller,
          current_attempt,
          simulation_id,
          half_random_mode
        )

      {:unique, updated_controller} ->
        handle_unique_attempt(
          generated,
          strategy,
          target_numbers,
          max_attempts,
          timeout_seconds,
          start_time,
          updated_controller,
          current_attempt,
          simulation_id,
          half_random_mode
        )
    end
  end

  defp handle_unique_attempt(
         generated,
         strategy,
         target_numbers,
         max_attempts,
         timeout_seconds,
         start_time,
         duplicate_controller,
         current_attempt,
         simulation_id,
         half_random_mode
       ) do
    if matches_target?(generated, target_numbers) do
      {:success, current_attempt + 1, generated, duplicate_controller}
    else
      # Broadcast progress every 1000 attempts for more frequent updates
      # Also broadcast at the start (current_attempt == 0)
      if rem(current_attempt, 1_000) == 0 || current_attempt == 0 do
        broadcast_progress(simulation_id, current_attempt, start_time)
      end

      # Continue simulation
      simulate_until_match(
        strategy,
        target_numbers,
        max_attempts,
        timeout_seconds,
        start_time,
        duplicate_controller,
        current_attempt + 1,
        simulation_id,
        half_random_mode
      )
    end
  end

  defp matches_target?(generated, target_numbers) do
    # Check if we matched 5+2 (main + euro)
    main_match =
      MapSet.new(generated.main) == MapSet.new(target_numbers.main_numbers)

    euro_match =
      MapSet.new(generated.euro) == MapSet.new(target_numbers.euro_numbers)

    main_match && euro_match
  end

  defp broadcast_progress(simulation_id, attempts, start_time) do
    duration = System.monotonic_time(:second) - start_time

    Phoenix.PubSub.broadcast(
      NumbersEvolution.PubSub,
      "simulation:#{simulation_id}",
      {:simulation_progress, simulation_id, %{attempts: attempts, duration_seconds: duration}}
    )
  end

  defp finalize_simulation(simulation_id, result, start_time, strategy, duplicate_controller) do
    simulation = Repo.get!(Simulation, simulation_id)
    duration = System.monotonic_time(:second) - start_time

    # Pobierz statystyki duplikatów
    duplicate_stats = SimulationDuplicateController.get_stats(duplicate_controller)

    case result do
      {:success, attempts, matched_numbers, _controller} ->
        result_data = %{
          matched_main: matched_numbers.main,
          matched_euro: matched_numbers.euro,
          attempts_count: attempts,
          duplicates_skipped: duplicate_stats.duplicates_skipped,
          unique_attempts: attempts,
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
          unique_attempts: attempts
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
          unique_attempts: 0
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

      strategy = Repo.get!(NumbersEvolution.Strategies.Strategy, strategy_id)

      strategy
      |> NumbersEvolution.Strategies.Strategy.performance_changeset(median)
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
