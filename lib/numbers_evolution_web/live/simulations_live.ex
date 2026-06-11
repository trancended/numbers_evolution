defmodule NumbersEvolutionWeb.SimulationsLive do
  @moduledoc """
  LiveView for simulation management - create, monitor, and manage simulations.
  """
  use NumbersEvolutionWeb, :live_view

  alias NumbersEvolution.{Accounts, Draws, Games, Simulations, Strategies}
  alias NumbersEvolution.Strategies.Generator
  alias NumbersEvolutionWeb.SimulationHelpers

  import NumbersEvolutionWeb.SimulationComponents

  # ============================================================================
  # LiveView Callbacks
  # ============================================================================

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    if current_user do
      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:page_title, "Symulacje - Numbers Evolution")
        |> assign(:active_section, :simulations)
        |> assign(:show_update_max_attempts_modal, false)
        |> assign(:update_max_attempts_simulation_id, nil)
        |> assign(:update_max_attempts_form, to_form(%{}, as: :update_max_attempts))
        |> assign(:show_update_timeout_modal, false)
        |> assign(:update_timeout_simulation_id, nil)
        |> assign(:update_timeout_form, to_form(%{}, as: :update_timeout))
        |> assign(:show_restart_simulation_modal, false)
        |> assign(:restart_simulation_id, nil)
        |> assign(:restart_simulation, nil)
        |> assign(:show_simulation_details_modal, false)
        |> assign(:simulation_details, nil)
        |> assign(:live_attempts, %{})
        |> assign(:live_prize_tiers, %{})
        |> assign(:selected_strategy, nil)
        |> assign(:strategy_pools, %{})
        |> assign(:target_validation_error, nil)
        |> assign(:half_random_mode, false)
        |> assign(:selected_game, Games.default_id())
        |> load_simulations()
        |> subscribe_to_running_simulations()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # Event Handlers - Navigation
  # ============================================================================

  @impl true
  def handle_event("logout", _params, socket) do
    session = socket.private[:session] || %{}
    token = Map.get(session, "user_token")
    if token, do: Accounts.delete_user_session_token(token)

    {:noreply,
     socket
     |> put_flash(:info, "Wylogowano pomyślnie")
     |> redirect(to: "/?logout=true")}
  end

  # ============================================================================
  # Event Handlers - Simulation Form
  # ============================================================================

  @impl true
  def handle_event("strategy_changed", %{"strategy_id" => strategy_id}, socket) do
    game_id = selected_game(socket)

    socket =
      if strategy_id != "" do
        strategy = Strategies.get_strategy!(socket.assigns.current_user, strategy_id)
        half_random_mode = socket.assigns.half_random_mode

        pools =
          Generator.get_strategy_pools(strategy,
            half_random_mode: half_random_mode,
            game: game_id
          )

        # Filter draws if strategy is VIP (requires constraints)
        all_draws = Draws.list_draws(limit: 50, game_type: game_id)
        filtered_draws = filter_draws_for_strategy(all_draws, strategy)

        socket
        |> assign(:selected_strategy, strategy)
        |> assign(:strategy_pools, pools)
        |> assign(:draws, filtered_draws)
        |> assign(:target_validation_error, nil)
      else
        # No strategy selected - show all draws
        all_draws = Draws.list_draws(limit: 50, game_type: game_id)

        socket
        |> assign(:selected_strategy, nil)
        |> assign(:strategy_pools, %{})
        |> assign(:draws, all_draws)
        |> assign(:target_validation_error, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("game_changed", %{"game_type" => game_id}, socket) do
    game_id = if Games.supported?(game_id), do: game_id, else: Games.default_id()

    draws = Draws.list_draws(limit: 50, game_type: game_id)

    {draws, pools} =
      case socket.assigns[:selected_strategy] do
        nil ->
          {draws, socket.assigns.strategy_pools}

        strategy ->
          pools =
            Generator.get_strategy_pools(strategy,
              half_random_mode: socket.assigns.half_random_mode,
              game: game_id
            )

          {filter_draws_for_strategy(draws, strategy), pools}
      end

    {:noreply,
     socket
     |> assign(:selected_game, game_id)
     |> assign(:draws, draws)
     |> assign(:strategy_pools, pools)
     |> assign(:target_validation_error, nil)}
  end

  @impl true
  def handle_event("half_random_mode_changed", %{"half_random_mode" => half_random_mode}, socket) do
    half_random_enabled = half_random_mode == "true"

    socket =
      socket
      |> assign(:half_random_mode, half_random_enabled)

    # Update strategy pools if strategy is selected
    socket =
      if socket.assigns[:selected_strategy] do
        strategy = socket.assigns.selected_strategy

        pools =
          Generator.get_strategy_pools(strategy,
            half_random_mode: half_random_enabled,
            game: selected_game(socket)
          )

        socket
        |> assign(:strategy_pools, pools)
        |> assign(:target_validation_error, nil)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("target_draw_changed", %{"target_draw_id" => target_draw_id}, socket) do
    socket =
      if target_draw_id != "" and socket.assigns[:selected_strategy] do
        target_draw = Draws.get_draw!(target_draw_id)
        strategy = socket.assigns.selected_strategy
        pools = socket.assigns.strategy_pools

        validation_result = validate_target_in_strategy_pools(target_draw, pools, strategy)

        case validation_result do
          {:error, reason} ->
            assign(socket, :target_validation_error, reason)

          :ok ->
            assign(socket, :target_validation_error, nil)
        end
      else
        assign(socket, :target_validation_error, nil)
      end

    {:noreply, socket}
  end

  # ============================================================================
  # Event Handlers - Simulation Actions
  # ============================================================================

  @impl true
  def handle_event("start_simulation", params, socket) do
    user = socket.assigns.current_user

    case Simulations.create_and_start_simulation(user, params) do
      {:ok, simulation} ->
        handle_simulation_started(socket, simulation, user, params)

      {:error, error} ->
        {:noreply, handle_simulation_error(socket, error)}
    end
  end

  @impl true
  def handle_event("restart_simulation", %{"id" => simulation_id} = params, socket) do
    user = socket.assigns.current_user

    # Remove the id from params since it's not needed for restart options
    restart_params = Map.delete(params, "id")

    case Simulations.restart_simulation(user, simulation_id, restart_params) do
      {:ok, simulation} ->
        socket =
          socket
          |> put_flash(:info, "Symulacja została zaktualizowana i uruchomiona ponownie!")
          |> load_simulations()
          |> subscribe_to_simulation(simulation.id)

        {:noreply, socket}

      {:error, :simulation_running} ->
        {:noreply,
         put_flash(socket, :error, "Nie można zaktualizować symulacji - jest już uruchomiona")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}

      {:error, changeset} when is_struct(changeset) ->
        errors = translate_errors(changeset)
        {:noreply, put_flash(socket, :error, "Błąd walidacji: #{errors}")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Nie udało się zaktualizować symulacji: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("retry_simulation", %{"id" => simulation_id}, socket) do
    user = socket.assigns.current_user

    case Simulations.retry_simulation(user, simulation_id) do
      {:ok, simulation} ->
        socket =
          socket
          |> put_flash(:info, "Symulacja została ponownie uruchomiona")
          |> load_simulations()
          |> subscribe_to_simulation(simulation.id)

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}

      {:error, :not_retryable} ->
        {:noreply, put_flash(socket, :error, "Tylko symulacje z błędem można ponowić")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Nie udało się ponowić symulacji: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("stop_simulation", %{"id" => simulation_id}, socket) do
    user = socket.assigns.current_user

    case Simulations.stop_simulation(user, simulation_id) do
      {:ok, _simulation} ->
        # Clean up live tracking data and unsubscribe from PubSub
        sim_id_string = to_string(simulation_id)
        live_attempts = Map.delete(socket.assigns.live_attempts || %{}, sim_id_string)
        live_prize_tiers = Map.delete(socket.assigns.live_prize_tiers || %{}, sim_id_string)

        socket =
          socket
          |> assign(:live_attempts, live_attempts)
          |> assign(:live_prize_tiers, live_prize_tiers)
          |> unsubscribe_from_simulation(simulation_id)
          |> put_flash(:info, "Symulacja została zatrzymana")
          |> load_simulations()

        {:noreply, socket}

      {:error, :not_running} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie jest uruchomiona")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}
    end
  end

  @impl true
  def handle_event("resume_simulation", %{"id" => simulation_id}, socket) do
    user = socket.assigns.current_user

    case Simulations.resume_simulation(user, simulation_id) do
      {:ok, simulation} ->
        socket =
          socket
          |> put_flash(:info, "Symulacja została wznowiona")
          |> load_simulations()
          |> subscribe_to_simulation(simulation.id)

        {:noreply, socket}

      {:error, :not_cancelled} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie może zostać wznowiona")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}
    end
  end

  @impl true
  def handle_event("delete_simulation", %{"id" => simulation_id}, socket) do
    user = socket.assigns.current_user

    case Simulations.delete_simulation(user, simulation_id) do
      {:ok, _simulation} ->
        socket =
          socket
          |> put_flash(:info, "Symulacja została usunięta")
          |> load_simulations()

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}

      {:error, :stale_entry} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Symulacja została zmodyfikowana. Odśwież stronę i spróbuj ponownie."
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = translate_errors(changeset)
        {:noreply, put_flash(socket, :error, "Nie udało się usunąć symulacji: #{errors}")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Nie udało się usunąć symulacji: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("toggle_favorite", %{"id" => simulation_id}, socket) do
    user = socket.assigns.current_user

    case Simulations.toggle_favorite(user, simulation_id) do
      {:ok, simulation} ->
        favorite_text = if simulation.is_favorite, do: "oznaczona", else: "odznaczona"

        socket =
          socket
          |> put_flash(:info, "Symulacja została #{favorite_text}")
          |> load_simulations()

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Nie udało się oznaczyć symulacji: #{inspect(reason)}")}
    end
  end

  # ============================================================================
  # Event Handlers - Modals
  # ============================================================================

  @impl true
  def handle_event("show_update_max_attempts", %{"id" => simulation_id}, socket) do
    user = socket.assigns.current_user

    case Simulations.get_simulation_with_details(user, simulation_id) do
      %{status: "max_attempts_reached", options: options} ->
        current_max_attempts = get_in(options, ["max_attempts"]) || 1_000_000

        form_data = %{"max_attempts" => Integer.to_string(current_max_attempts)}
        form = to_form(form_data, as: :update_max_attempts)

        {:noreply,
         socket
         |> assign(:show_update_max_attempts_modal, true)
         |> assign(:update_max_attempts_simulation_id, simulation_id)
         |> assign(:update_max_attempts_form, form)}

      _ ->
        {:noreply, put_flash(socket, :error, "Symulacja nie może mieć zmienionego limitu prób")}
    end
  end

  @impl true
  def handle_event("close_update_max_attempts_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_update_max_attempts_modal, false)
     |> assign(:update_max_attempts_simulation_id, nil)}
  end

  @impl true
  def handle_event("update_max_attempts", %{"update_max_attempts" => params}, socket) do
    user = socket.assigns.current_user
    simulation_id = socket.assigns.update_max_attempts_simulation_id
    max_attempts = params["max_attempts"]

    case Integer.parse(max_attempts) do
      {max_attempts_int, _} when max_attempts_int > 0 ->
        case Simulations.update_max_attempts_and_retry(user, simulation_id, max_attempts_int) do
          {:ok, simulation} ->
            socket =
              socket
              |> assign(:show_update_max_attempts_modal, false)
              |> assign(:update_max_attempts_simulation_id, nil)
              |> put_flash(:info, "Symulacja została uruchomiona z nowym limitem prób")
              |> load_simulations()
              |> subscribe_to_simulation(simulation.id)

            {:noreply, socket}

          {:error, :not_found} ->
            {:noreply,
             socket
             |> assign(:show_update_max_attempts_modal, false)
             |> put_flash(:error, "Symulacja nie została znaleziona")}

          {:error, :not_retryable} ->
            {:noreply,
             socket
             |> assign(:show_update_max_attempts_modal, false)
             |> put_flash(:error, "Tylko symulacje z przekroczonym limitem prób można ponowić")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:show_update_max_attempts_modal, false)
             |> put_flash(:error, "Nie udało się zaktualizować limitu prób: #{inspect(reason)}")}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Nieprawidłowa wartość limitu prób")}
    end
  end

  @impl true
  def handle_event("show_update_timeout", %{"id" => simulation_id}, socket) do
    user = socket.assigns.current_user

    case Simulations.get_simulation_with_details(user, simulation_id) do
      %{status: "timeout", options: options} ->
        current_timeout = get_in(options, ["timeout_seconds"]) || 300

        form_data = %{"timeout_seconds" => Integer.to_string(current_timeout)}
        form = to_form(form_data, as: :update_timeout)

        {:noreply,
         socket
         |> assign(:show_update_timeout_modal, true)
         |> assign(:update_timeout_simulation_id, simulation_id)
         |> assign(:update_timeout_form, form)}

      _ ->
        {:noreply, put_flash(socket, :error, "Symulacja nie może mieć zmienionego czasu trwania")}
    end
  end

  @impl true
  def handle_event("close_update_timeout_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_update_timeout_modal, false)
     |> assign(:update_timeout_simulation_id, nil)}
  end

  @impl true
  def handle_event("update_timeout", %{"update_timeout" => params}, socket) do
    user = socket.assigns.current_user
    simulation_id = socket.assigns.update_timeout_simulation_id
    timeout_seconds = params["timeout_seconds"]

    case Integer.parse(timeout_seconds) do
      {timeout_int, _} when timeout_int > 0 ->
        case Simulations.update_timeout_and_retry(user, simulation_id, timeout_int) do
          {:ok, simulation} ->
            socket =
              socket
              |> assign(:show_update_timeout_modal, false)
              |> assign(:update_timeout_simulation_id, nil)
              |> put_flash(:info, "Symulacja została uruchomiona z nowym czasem trwania")
              |> load_simulations()
              |> subscribe_to_simulation(simulation.id)

            {:noreply, socket}

          {:error, :not_found} ->
            {:noreply,
             socket
             |> assign(:show_update_timeout_modal, false)
             |> put_flash(:error, "Symulacja nie została znaleziona")}

          {:error, :not_retryable} ->
            {:noreply,
             socket
             |> assign(:show_update_timeout_modal, false)
             |> put_flash(:error, "Tylko symulacje z timeout można ponowić")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:show_update_timeout_modal, false)
             |> put_flash(:error, "Nie udało się zaktualizować czasu trwania: #{inspect(reason)}")}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Nieprawidłowa wartość czasu trwania")}
    end
  end

  @impl true
  def handle_event("show_restart_simulation", %{"id" => simulation_id}, socket) do
    user = socket.assigns.current_user

    case Simulations.get_simulation_with_details(user, simulation_id) do
      %{} = simulation ->
        socket =
          socket
          |> assign(:show_restart_simulation_modal, true)
          |> assign(:restart_simulation_id, simulation_id)
          |> assign(:restart_simulation, simulation)

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}
  end

  @impl true
  def handle_event("close_restart_simulation_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_restart_simulation_modal, false)
     |> assign(:restart_simulation_id, nil)
     |> assign(:restart_simulation, nil)}
  end

  @impl true
  def handle_event("show_simulation_details", %{"id" => simulation_id}, socket) do
    user = socket.assigns.current_user

    case Simulations.get_simulation_with_details(user, simulation_id) do
      {:ok, simulation} ->
        {:noreply,
         socket
         |> assign(:show_simulation_details_modal, true)
         |> assign(:simulation_details, simulation)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}
    end
  end

  @impl true
  def handle_event("close_simulation_details", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_simulation_details_modal, false)
     |> assign(:simulation_details, nil)}
  end

  # ============================================================================
  # PubSub Handlers for Real-time Updates
  # ============================================================================

  @impl true
  def handle_info({:simulation_progress, simulation_id, %{attempts: attempts} = progress}, socket) do
    sim_id_string = to_string(simulation_id)
    live_attempts = Map.put(socket.assigns.live_attempts || %{}, sim_id_string, attempts)

    live_prize_tiers =
      if Map.has_key?(progress, :prize_tiers) do
        Map.put(socket.assigns.live_prize_tiers || %{}, sim_id_string, progress.prize_tiers)
      else
        socket.assigns.live_prize_tiers || %{}
      end

    {:noreply, assign(socket, live_attempts: live_attempts, live_prize_tiers: live_prize_tiers)}
  end

  @impl true
  def handle_info({:simulation_complete, simulation}, socket) do
    simulation_id = simulation.id
    live_attempts = Map.delete(socket.assigns.live_attempts || %{}, simulation_id)
    live_prize_tiers = Map.delete(socket.assigns.live_prize_tiers || %{}, simulation_id)

    socket =
      socket
      |> assign(:live_attempts, live_attempts)
      |> assign(:live_prize_tiers, live_prize_tiers)
      |> unsubscribe_from_simulation(simulation_id)
      |> load_simulations()

    {:noreply, socket}
  end

  # Fallback handler for unknown messages
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ============================================================================
  # Private Functions - Simulation Helpers
  # ============================================================================

  defp handle_simulation_started(socket, simulation, user, params) do
    strategy = Strategies.get_strategy!(user, params["strategy_id"])
    target_draw = Draws.get_draw!(params["target_draw_id"])

    main_numbers = Enum.join(target_draw.numbers.main_numbers, ", ")

    euro_info =
      case target_draw.numbers.euro_numbers do
        [] -> ""
        euro -> " | #{Enum.join(euro, ", ")}"
      end

    target_info =
      "Strategia '#{strategy.name}' poszukuje liczb: #{main_numbers}#{euro_info}"

    vip1_info = format_vip1_info(simulation.options)

    socket =
      socket
      |> put_flash(:info, "Symulacja została uruchomiona w tle. #{target_info}#{vip1_info}")
      |> load_simulations()
      |> subscribe_to_simulation(simulation.id)

    {:noreply, socket}
  end

  defp format_vip1_info(%{"vip1_mode" => true, "vip1_pool" => pool}) when not is_nil(pool) do
    euro_info =
      case pool["euro_pool"] do
        euro when euro in [nil, []] -> ""
        euro -> ", #{length(euro)} euro"
      end

    "\n🎰 Tryb VIP1 aktywny - pula: #{length(pool["main_pool"])} głównych#{euro_info}"
  end

  defp format_vip1_info(_), do: ""

  defp handle_simulation_error(socket, :strategy_not_found) do
    put_flash(socket, :error, "Nie znaleziono strategii")
  end

  defp handle_simulation_error(socket, :draw_not_found) do
    put_flash(socket, :error, "Nie znaleziono losowania")
  end

  defp handle_simulation_error(socket, %{type: :vip1_pool_invalid} = error) do
    put_flash(socket, :error, format_vip1_pool_error(error))
  end

  defp handle_simulation_error(socket, %{type: :vip2_blacklist_invalid} = error) do
    put_flash(socket, :error, format_vip2_blacklist_error(error))
  end

  defp handle_simulation_error(socket, %{type: :vip_constraints_not_met} = error) do
    put_flash(socket, :error, format_vip_constraints_error(error))
  end

  defp handle_simulation_error(socket, %{type: :vip1_pool_generation_failed}) do
    put_flash(
      socket,
      :error,
      "🎰 VIP1: Nie udało się wygenerować prawidłowej puli po 100 próbach. To bardzo rzadkie - spróbuj ponownie lub wybierz inne losowanie."
    )
  end

  defp handle_simulation_error(socket, %{type: :vip2_blacklist_generation_failed}) do
    put_flash(
      socket,
      :error,
      "🎲 VIP2: Nie udało się wygenerować prawidłowego blacklistu po 100 próbach. To bardzo rzadkie - spróbuj ponownie lub wybierz inne losowanie."
    )
  end

  defp handle_simulation_error(socket, changeset) when is_struct(changeset) do
    errors = translate_errors(changeset)
    put_flash(socket, :error, "Błąd walidacji: #{errors}")
  end

  defp handle_simulation_error(socket, reason) do
    put_flash(socket, :error, "Nie udało się uruchomić symulacji: #{inspect(reason)}")
  end

  defp format_vip1_pool_error(error) do
    missing_main = Enum.join(error.missing_main, ", ")
    missing_euro = Enum.join(error.missing_euro, ", ")

    pool_info =
      "Wylosowana pula: Główne [#{Enum.join(error.pool.main_pool, ", ")}] Euro [#{Enum.join(error.pool.euro_pool, ", ")}]"

    cond do
      missing_main != "" and missing_euro != "" ->
        "🎰 VIP1: Wylosowany zestaw nie zawiera liczb głównych: #{missing_main} oraz euro: #{missing_euro}. #{pool_info} Ponów próbę!"

      missing_main != "" ->
        "🎰 VIP1: Wylosowany zestaw nie zawiera liczb głównych: #{missing_main}. #{pool_info} Ponów próbę!"

      true ->
        "🎰 VIP1: Wylosowany zestaw nie zawiera liczb euro: #{missing_euro}. #{pool_info} Ponów próbę!"
    end
  end

  defp format_vip2_blacklist_error(error) do
    blocked_main = Enum.join(error.blocked_main, ", ")
    blocked_euro = Enum.join(error.blocked_euro, ", ")

    available_info =
      "Dostępne liczby: Główne [#{Enum.join(error.main_available, ", ")}] Euro [#{Enum.join(error.euro_available, ", ")}]"

    cond do
      blocked_main != "" and blocked_euro != "" ->
        "🎲 VIP2: Losowy blacklist wykluczył poszukiwane liczby główne: #{blocked_main} oraz euro: #{blocked_euro}. #{available_info} Ponów próbę!"

      blocked_main != "" ->
        "🎲 VIP2: Losowy blacklist wykluczył poszukiwane liczby główne: #{blocked_main}. #{available_info} Ponów próbę!"

      true ->
        "🎲 VIP2: Losowy blacklist wykluczył poszukiwane liczby euro: #{blocked_euro}. #{available_info} Ponów próbę!"
    end
  end

  defp format_vip_constraints_error(error) do
    target_main = Enum.join(error.target_main, ", ")
    target_euro = Enum.join(error.target_euro, ", ")
    constraints_list = Enum.join(error.constraints, " • ")

    """
    ❌ Tryb VIP (VIP1/VIP2) wymaga aby poszukiwane liczby spełniały ograniczenia:
    • Dokładnie 2 nieparzyste + 3 parzyste liczby główne
    • Maksymalnie 2 liczby w jednej dziesiątce

    Poszukiwane liczby: [#{target_main}] + [#{target_euro}]

    Problemy:
    #{constraints_list}

    Wybierz inne losowanie lub wyłącz tryb VIP.
    """
  end

  # ============================================================================
  # Private Functions - Data Loading
  # ============================================================================

  defp load_simulations(socket) do
    user = socket.assigns.current_user
    strategies = if user, do: Strategies.list_strategies(user), else: []
    simulations = if user, do: Simulations.list_simulations(user), else: []
    draws = Draws.list_draws(limit: 50, game_type: selected_game(socket))
    strategy_pools = build_strategy_pools_map(simulations)

    socket
    |> assign(:strategies, strategies)
    |> assign(:simulations, simulations)
    |> assign(:draws, draws)
    |> assign(:strategy_pools, strategy_pools)
    |> assign(:selected_strategy, nil)
    |> assign(:target_validation_error, nil)
  end

  defp build_strategy_pools_map(simulations) do
    simulations
    |> Enum.filter(fn sim ->
      Ecto.assoc_loaded?(sim.strategy) && sim.strategy != nil
    end)
    |> Enum.reduce(%{}, fn sim, acc ->
      pools = SimulationHelpers.get_pools_for_simulation(sim)
      Map.put(acc, sim.id, pools)
    end)
  end

  defp selected_game(socket) do
    Map.get(socket.assigns, :selected_game) || Games.default_id()
  end

  # Filter draws to show only those that meet strategy constraints
  defp filter_draws_for_strategy(draws, strategy) do
    Enum.filter(draws, fn draw ->
      draw_meets_strategy_constraints?(draw, strategy)
    end)
  end

  defp draw_meets_strategy_constraints?(draw, strategy) do
    case Generator.validate_strategy_constraints(
           strategy,
           draw.numbers.main_numbers,
           draw.numbers.euro_numbers,
           draw_game_id(draw)
         ) do
      :ok -> true
      {:error, _} -> false
    end
  end

  defp draw_game_id(draw) do
    if Games.supported?(draw.game_type), do: draw.game_type, else: Games.default_id()
  end

  @doc """
  Validates if target draw numbers exist in strategy pools and meet strategy constraints.
  """
  def validate_target_in_strategy_pools(target_draw, strategy_pools, strategy) do
    main_target = target_draw.numbers.main_numbers
    euro_target = target_draw.numbers.euro_numbers

    # First check strategy constraints (even/odd ratio, blacklist, etc.)
    case Generator.validate_strategy_constraints(
           strategy,
           main_target,
           euro_target,
           draw_game_id(target_draw)
         ) do
      {:error, constraint_errors} ->
        {:error, format_constraint_errors(constraint_errors)}

      :ok ->
        # Then check if numbers exist in strategy pools
        validate_pools_contain_target(main_target, euro_target, strategy_pools)
    end
  end

  defp format_constraint_errors(errors) do
    """
    ❌ Losowanie nie spełnia wymogów strategii:

    #{Enum.map_join(errors, "\n", &"• #{&1}")}

    Wybierz inne losowanie pasujące do strategii.
    """
  end

  defp validate_pools_contain_target(main_target, euro_target, strategy_pools) do
    main_pools = strategy_pools.main_numbers
    euro_pools = strategy_pools.euro_numbers

    # Check main numbers
    missing_main =
      Enum.filter(main_target, fn num ->
        not (num in main_pools.hot or num in main_pools.cold or num in main_pools.random)
      end)

    # Check euro numbers
    missing_euro =
      Enum.filter(euro_target, fn num ->
        not (num in euro_pools.hot or num in euro_pools.random)
      end)

    cond do
      not Enum.empty?(missing_main) and not Enum.empty?(missing_euro) ->
        {:error,
         "Poszukiwane liczby główne #{Enum.join(missing_main, ", ")} oraz euro #{Enum.join(missing_euro, ", ")} nie istnieją w komplecie strategii. Rozważ reset strategii."}

      not Enum.empty?(missing_main) ->
        {:error,
         "Poszukiwane liczby główne #{Enum.join(missing_main, ", ")} nie istnieją w komplecie strategii. Rozważ reset strategii."}

      not Enum.empty?(missing_euro) ->
        {:error,
         "Poszukiwane liczby euro #{Enum.join(missing_euro, ", ")} nie istnieją w komplecie strategii. Rozważ reset strategii."}

      true ->
        :ok
    end
  end

  # ============================================================================
  # Private Functions - Utilities
  # ============================================================================

  defp translate_errors(changeset) do
    changeset.errors
    |> Enum.map_join(", ", fn {field, {message, _}} -> "#{field}: #{message}" end)
  end

  # ============================================================================
  # Private Functions - Authentication
  # ============================================================================

  defp get_current_user(session) do
    case Map.get(session, "user_token") do
      token when is_binary(token) ->
        case Accounts.verify_user_token(token) do
          {:ok, user} -> user
          {:error, _} -> nil
        end

      _ ->
        nil
    end
  end

  # ============================================================================
  # PubSub Subscription Helpers
  # ============================================================================

  defp subscribe_to_running_simulations(socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      running_simulations = Simulations.list_simulations(user, status: "running")

      Enum.reduce(running_simulations, socket, fn simulation, acc ->
        subscribe_to_simulation(acc, simulation.id)
      end)
    else
      socket
    end
  end

  defp subscribe_to_simulation(socket, simulation_id) do
    if connected?(socket) do
      topic = "simulation:#{simulation_id}"
      Phoenix.PubSub.subscribe(NumbersEvolution.PubSub, topic)
      socket
    else
      socket
    end
  end

  defp unsubscribe_from_simulation(socket, simulation_id) do
    if connected?(socket) do
      topic = "simulation:#{simulation_id}"
      Phoenix.PubSub.unsubscribe(NumbersEvolution.PubSub, topic)
      socket
    else
      socket
    end
  end

  # ============================================================================
  # Render Function
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_scope={:simulations}>
      <main class="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <.simulations_section
          strategies={@strategies}
          simulations={@simulations}
          draws={@draws}
          live_attempts={@live_attempts}
          live_prize_tiers={@live_prize_tiers}
          strategy_pools={@strategy_pools}
          selected_strategy={@selected_strategy}
          selected_game={@selected_game}
          target_validation_error={@target_validation_error}
        />
      </main>

      <%!-- Modals --%>
      <%= if @show_update_max_attempts_modal do %>
        <.modal
          id="update-max-attempts-modal"
          show={true}
          on_cancel={JS.push("close_update_max_attempts_modal")}
        >
          <:title>Zmień limit prób</:title>
          <.form
            for={@update_max_attempts_form}
            id="update-max-attempts-form"
            phx-submit="update_max_attempts"
          >
            <.input
              field={@update_max_attempts_form[:max_attempts]}
              type="number"
              label="Nowy limit prób"
              min="1"
              required
            />
            <p class="text-sm text-base-content/70 mt-2">
              Symulacja zostanie uruchomiona ponownie z nowym limitem prób.
            </p>
            <div class="modal-action">
              <button
                type="button"
                phx-click="close_update_max_attempts_modal"
                class="btn"
              >
                Anuluj
              </button>
              <button type="submit" class="btn btn-primary">
                Uruchom z nowym limitem
              </button>
            </div>
          </.form>
        </.modal>
      <% end %>

      <%= if @show_update_timeout_modal do %>
        <.modal
          id="update-timeout-modal"
          show={true}
          on_cancel={JS.push("close_update_timeout_modal")}
        >
          <:title>Zmień timeout</:title>
          <.form
            for={@update_timeout_form}
            id="update-timeout-form"
            phx-submit="update_timeout"
          >
            <.input
              field={@update_timeout_form[:timeout_seconds]}
              type="number"
              label="Nowy timeout (sekundy)"
              min="10"
              max="86400"
              required
            />
            <p class="text-sm text-base-content/70 mt-2">
              Symulacja zostanie uruchomiona ponownie z nowym czasem trwania.
            </p>
            <div class="modal-action">
              <button
                type="button"
                phx-click="close_update_timeout_modal"
                class="btn"
              >
                Anuluj
              </button>
              <button type="submit" class="btn btn-primary">
                Uruchom z nowym timeoutem
              </button>
            </div>
          </.form>
        </.modal>
      <% end %>

      <%= if @show_restart_simulation_modal do %>
        <.modal
          id="restart-simulation-modal"
          show={true}
          on_cancel={JS.push("close_restart_simulation_modal")}
        >
          <:title>Uruchom ponownie symulację</:title>
          <%= if @restart_simulation do %>
            <div class="space-y-4">
              <div class="bg-base-200 p-4 rounded-lg">
                <h4 class="font-semibold mb-2">Aktualne ustawienia symulacji:</h4>
                <div class="space-y-2 text-sm">
                  <div><strong>Strategia:</strong> {@restart_simulation.strategy.name}</div>
                  <div>
                    <strong>Maksymalna liczba prób:</strong> {format_number(
                      @restart_simulation.options["max_attempts"] || 1_000_000
                    )}
                  </div>
                  <div>
                    <strong>Timeout:</strong> {format_number(
                      @restart_simulation.options["timeout_seconds"] || 86400
                    )} sekund
                  </div>
                </div>
              </div>

              <div class="alert alert-info">
                <span class="hero-exclamation-triangle size-5 shrink-0"></span>
                <div>
                  <p class="font-semibold">
                    Symulacja zostanie zaktualizowana i uruchomiona ponownie
                  </p>
                  <p>
                    Wprowadź nowe parametry poniżej. Wszystkie dotychczasowe wyniki zostaną wyczyszczone.
                  </p>
                </div>
              </div>

              <.form
                for={%{}}
                id="restart-simulation-form"
                phx-submit="restart_simulation"
                phx-value-id={@restart_simulation_id}
              >
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div class="form-control">
                    <label class="label mb-3">
                      <span class="label-text">Maksymalna liczba prób</span>
                    </label>
                    <input
                      type="number"
                      name="max_attempts"
                      class="input input-bordered"
                      placeholder={@restart_simulation.options["max_attempts"] || "1000000"}
                      min="1000"
                      max="999999999"
                    />
                  </div>

                  <div class="form-control">
                    <label class="label mb-3">
                      <span class="label-text">Timeout (sekundy)</span>
                    </label>
                    <input
                      type="number"
                      name="timeout_seconds"
                      class="input input-bordered"
                      placeholder={@restart_simulation.options["timeout_seconds"] || "86400"}
                      min="10"
                      max="86400"
                    />
                  </div>
                </div>

                <div class="modal-action">
                  <button
                    type="button"
                    phx-click="close_restart_simulation_modal"
                    class="btn"
                  >
                    Anuluj
                  </button>
                  <button type="submit" class="btn btn-primary">
                    <.icon name="hero-arrow-path" class="size-5" /> Uruchom ponownie
                  </button>
                </div>
              </.form>
            </div>
          <% end %>
        </.modal>
      <% end %>

      <%= if @show_simulation_details_modal do %>
        <.simulation_details_modal simulation={@simulation_details} show={true} />
      <% end %>
    </Layouts.app>
    """
  end
end
