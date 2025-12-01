defmodule NumbersEvolutionWeb.PageLive do
  @moduledoc """
  Main LiveView for Numbers Evolution SPA.
  Manages all sections through @active_section assign.

  This LiveView acts as a coordinator:
  - Handles user authentication
  - Manages section navigation
  - Loads data for active sections
  - Delegates rendering to stateless function components
  """
  use NumbersEvolutionWeb, :live_view

  alias NumbersEvolution.{Accounts, Draws, Repo, Simulations, Strategies}
  alias NumbersEvolution.Strategies.Generator

  import Ecto.Query

  # Import section components
  import NumbersEvolutionWeb.PageComponents
  import NumbersEvolutionWeb.SectionsComponents
  import NumbersEvolutionWeb.Layouts

  # ============================================================================
  # LiveView Callbacks
  # ============================================================================

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:active_section, get_initial_section(current_user))
      |> assign(:page_title, "Numbers Evolution")
      |> assign(:show_register_form, false)
      |> assign(:show_login_form, false)
      |> assign(:show_update_max_attempts_modal, false)
      |> assign(:update_max_attempts_simulation_id, nil)
      |> assign(:update_max_attempts_form, to_form(%{}, as: :update_max_attempts))
      |> assign(:show_update_timeout_modal, false)
      |> assign(:update_timeout_simulation_id, nil)
      |> assign(:update_timeout_form, to_form(%{}, as: :update_timeout))
      |> assign(:show_restart_simulation_modal, false)
      |> assign(:restart_simulation_id, nil)
      |> assign(:show_simulation_details_modal, false)
      |> assign(:simulation_details, nil)
      |> assign(:register_form, to_form(%{}, as: :user))
      |> assign(:login_form, to_form(%{}, as: :user))
      |> assign(:live_attempts, %{})
      |> assign(:live_prize_tiers, %{})
      |> assign(:selected_strategy, nil)
      |> assign(:strategy_pools, %{})
      |> assign(:target_validation_error, nil)
      |> assign(:half_random_mode, false)
      |> initialize_section_data(current_user)
      |> load_dashboard_data_if_user(current_user)
      |> subscribe_to_running_simulations(current_user)

    {:ok, socket}
  end

  defp load_dashboard_data_if_user(socket, nil), do: socket
  defp load_dashboard_data_if_user(socket, _user), do: load_dashboard_data(socket)

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      if Map.get(params, "logout") == "true" do
        handle_logout_params(socket)
      else
        handle_token_params(socket, params)
      end

    {:noreply, socket}
  end

  defp handle_logout_params(socket) do
    socket
    |> assign(:current_user, nil)
    |> assign(:active_section, :landing)
    |> assign(:user_stats, %{strategies_count: 0, simulations_count: 0, best_strategy: nil})
    |> assign(:recent_simulations, [])
    |> push_patch(to: "/", replace: true)
  end

  defp handle_token_params(socket, params) do
    case Map.get(params, "token") do
      token when is_binary(token) ->
        verify_and_login_with_token(socket, token)

      _ ->
        socket
    end
  end

  defp verify_and_login_with_token(socket, token) do
    case Accounts.verify_user_token(token) do
      {:ok, user} ->
        socket
        |> assign(:current_user, user)
        |> assign(:active_section, :dashboard)
        |> load_dashboard_data()
        |> push_patch(to: "/", replace: true)

      {:error, _} ->
        socket
    end
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  @impl true
  def handle_event("navigate", %{"section" => section}, socket) do
    section_atom = String.to_existing_atom(section)

    # Check admin access for admin section
    if section_atom == :admin do
      current_user = socket.assigns.current_user

      if admin?(current_user) do
        socket =
          socket
          |> assign(:active_section, section_atom)
          |> load_section_data(section_atom)

        {:noreply, socket}
      else
        {:noreply,
         socket
         |> put_flash(:error, "Brak dostępu do panelu administratora")
         |> assign(:active_section, :dashboard)}
      end
    else
      socket =
        socket
        |> assign(:active_section, section_atom)
        |> load_section_data(section_atom)

      {:noreply, socket}
    end
  end

  # Authentication events
  @impl true
  def handle_event("show_register_form", _params, socket) do
    form = to_form(%{}, as: :user)

    {:noreply,
     socket
     |> assign(:show_register_form, true)
     |> assign(:register_form, form)}
  end

  @impl true
  def handle_event("show_login_form", _params, socket) do
    form = to_form(%{}, as: :user)

    {:noreply,
     socket
     |> assign(:show_login_form, true)
     |> assign(:login_form, form)}
  end

  @impl true
  def handle_event("close_auth_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_register_form, false)
     |> assign(:show_login_form, false)}
  end

  @impl true
  def handle_event("validate_register", %{"user" => user_params}, socket) do
    # Only validate if user has started typing meaningful content
    email = Map.get(user_params, "email", "")

    changeset =
      if String.length(email) > 2 do
        %Accounts.User{}
        |> Accounts.User.registration_changeset(user_params)
        |> Map.put(:action, :validate)
      else
        %Accounts.User{}
        |> Accounts.User.registration_changeset(user_params)
      end

    form = to_form(changeset, as: :user)
    {:noreply, assign(socket, :register_form, form)}
  end

  @impl true
  def handle_event("validate_login", %{"user" => user_params}, socket) do
    form = to_form(user_params, as: :user)
    {:noreply, assign(socket, :login_form, form)}
  end

  @impl true
  def handle_event("register", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        token = Accounts.generate_user_session_token(user)

        {:noreply,
         socket
         |> put_flash(:info, "Rejestracja zakończona sukcesem!")
         |> assign(:current_user, user)
         |> assign(:active_section, :dashboard)
         |> assign(:show_register_form, false)
         |> assign(:show_login_form, false)
         |> assign(:pending_session_token, token)
         |> load_dashboard_data()
         |> redirect(to: "/?token=#{token}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        form = to_form(changeset, as: :user)
        {:noreply, assign(socket, :register_form, form)}
    end
  end

  @impl true
  def handle_event("login", %{"user" => %{"email" => email, "password" => password}}, socket) do
    case Accounts.get_user_by_email_and_password(email, password) do
      {:ok, user} ->
        token = Accounts.generate_user_session_token(user)

        {:noreply,
         socket
         |> put_flash(:info, "Zalogowano pomyślnie!")
         |> assign(:current_user, user)
         |> assign(:active_section, :dashboard)
         |> assign(:show_register_form, false)
         |> assign(:show_login_form, false)
         |> assign(:pending_session_token, token)
         |> load_dashboard_data()
         |> redirect(to: "/?token=#{token}")}

      {:error, :invalid_credentials} ->
        {:noreply,
         socket
         |> put_flash(:error, "Nieprawidłowy email lub hasło")
         |> assign(:show_login_form, true)}
    end
  end

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

  # Strategies section events
  @impl true
  def handle_event("open_strategy_form", _params, socket) do
    {:noreply, assign(socket, :show_strategy_form, true)}
  end

  @impl true
  def handle_event("close_strategy_form", _params, socket) do
    {:noreply, assign(socket, :show_strategy_form, false)}
  end

  @impl true
  def handle_event("switch_strategy_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :strategy_form_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("delete_strategy", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Strategies.delete_strategy(user, id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Strategia została usunięta")
         |> load_strategies()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Błąd podczas usuwania strategii: #{inspect(changeset.errors)}"
         )}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Błąd podczas usuwania strategii: #{inspect(reason)}")}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "Nie znaleziono strategii")}
  end

  # Simulations section events
  @impl true
  def handle_event("strategy_changed", %{"strategy_id" => strategy_id}, socket) do
    if strategy_id != "" do
      strategy = Strategies.get_strategy!(socket.assigns.current_user, strategy_id)
      half_random_mode = socket.assigns.half_random_mode
      pools = Generator.get_strategy_pools(strategy, half_random_mode: half_random_mode)

      socket
      |> assign(:selected_strategy, strategy)
      |> assign(:strategy_pools, pools)
      |> assign(:target_validation_error, nil)
    else
      socket
      |> assign(:selected_strategy, nil)
      |> assign(:strategy_pools, %{})
      |> assign(:target_validation_error, nil)
    end

    {:noreply, socket}
  end

  def handle_event("half_random_mode_changed", %{"half_random_mode" => half_random_mode}, socket) do
    half_random_enabled = half_random_mode == "true"

    socket =
      socket
      |> assign(:half_random_mode, half_random_enabled)

    # Update strategy pools if strategy is selected
    socket =
      if socket.assigns[:selected_strategy] do
        strategy = socket.assigns.selected_strategy
        pools = Generator.get_strategy_pools(strategy, half_random_mode: half_random_enabled)

        socket
        |> assign(:strategy_pools, pools)
        |> assign(:target_validation_error, nil)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("target_draw_changed", %{"target_draw_id" => target_draw_id}, socket) do
    if target_draw_id != "" and socket.assigns[:selected_strategy] do
      target_draw = Draws.get_draw!(target_draw_id)
      _strategy = socket.assigns.selected_strategy
      pools = socket.assigns.strategy_pools

      validation_result = validate_target_in_strategy_pools(target_draw, pools)

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

  def handle_event("start_simulation", params, socket) do
    user = socket.assigns.current_user

    case Simulations.create_and_start_simulation(user, params) do
      {:ok, simulation} ->
        # Get strategy and target draw for display
        strategy = Strategies.get_strategy!(user, params["strategy_id"])
        target_draw = Draws.get_draw!(params["target_draw_id"])

        main_numbers = Enum.join(target_draw.numbers.main_numbers, ", ")
        euro_numbers = Enum.join(target_draw.numbers.euro_numbers, ", ")

        target_info =
          "Strategia '#{strategy.name}' poszukuje liczb: #{main_numbers} | #{euro_numbers}"

        socket =
          socket
          |> put_flash(:info, "Symulacja została uruchomiona w tle. #{target_info}")
          |> load_simulations()
          |> load_dashboard_data()
          |> subscribe_to_simulation(simulation.id)

        {:noreply, socket}

      {:error, :strategy_not_found} ->
        {:noreply, put_flash(socket, :error, "Nie znaleziono strategii")}

      {:error, :draw_not_found} ->
        {:noreply, put_flash(socket, :error, "Nie znaleziono losowania")}

      {:error, changeset} when is_struct(changeset) ->
        errors = translate_errors(changeset)
        {:noreply, put_flash(socket, :error, "Błąd walidacji: #{errors}")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Nie udało się uruchomić symulacji: #{inspect(reason)}")}
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
          |> load_dashboard_data()
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
          |> load_dashboard_data()
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
        socket =
          socket
          |> put_flash(:info, "Symulacja została zatrzymana")
          |> load_simulations()
          |> load_dashboard_data()

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
          |> load_dashboard_data()
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
          |> load_dashboard_data()

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
          |> load_dashboard_data()

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Symulacja nie została znaleziona")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Nie udało się oznaczyć symulacji: #{inspect(reason)}")}
    end
  end

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
              |> load_dashboard_data()
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
              |> load_dashboard_data()
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

  # Generator section events
  @impl true
  def handle_event("generate_coupons", params, socket) do
    %{"strategy_id" => strategy_id, "coupons_count" => count_str} = params

    with {count, _} <- Integer.parse(count_str),
         strategy when not is_nil(strategy) <- find_strategy(socket, strategy_id) do
      case generate_coupons_for_strategy(strategy, count) do
        {:ok, coupons} ->
          {:noreply,
           socket
           |> assign(:generated_coupons, coupons)
           |> assign(:selected_strategy_id, strategy_id)
           |> assign(:coupons_count, count)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Nie udało się wygenerować kuponów")}
      end
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Nieprawidłowe parametry")}
    end
  end

  @impl true
  def handle_event("regenerate_coupons", _params, socket) do
    strategy_id = socket.assigns[:selected_strategy_id]
    count = socket.assigns[:coupons_count] || 3

    if strategy_id do
      strategy = find_strategy(socket, strategy_id)

      case generate_coupons_for_strategy(strategy, count) do
        {:ok, coupons} ->
          {:noreply, assign(socket, :generated_coupons, coupons)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Nie udało się wygenerować kuponów")}
      end
    else
      {:noreply, socket}
    end
  end

  # Strategy creation events
  @impl true
  def handle_event("create_ai_strategy", %{"prompt" => prompt}, socket) do
    user = socket.assigns.current_user

    case Strategies.create_ai_strategy(user, prompt) do
      {:ok, strategy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Strategia '#{strategy.name}' została wygenerowana przez AI!")
         |> assign(:show_strategy_form, false)
         |> assign(:generated_strategy, nil)
         |> load_strategies()}

      {:error, :prompt_too_short} ->
        {:noreply, put_flash(socket, :error, "Prompt musi mieć minimum 10 znaków")}

      {:error, :prompt_too_long} ->
        {:noreply, put_flash(socket, :error, "Prompt nie może przekraczać 500 znaków")}

      {:error, :generation_failed} ->
        {:noreply,
         put_flash(socket, :error, "Nie udało się wygenerować strategii. Spróbuj ponownie.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = extract_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Błąd walidacji: #{errors}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Wystąpił nieoczekiwany błąd")}
    end
  end

  @impl true
  def handle_event("generate_ai_preview", %{"prompt" => prompt}, socket) do
    case NumbersEvolution.AIProvider.generate_strategy(prompt) do
      {:ok, strategy_data} ->
        {:noreply, assign(socket, :generated_strategy, strategy_data)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Nie udało się wygenerować podglądu")}
    end
  end

  @impl true
  def handle_event("use_strategy_template", %{"strategy" => strategy_name}, socket) do
    prompt = Strategies.OpenRouterService.build_strategy_prompt(strategy_name)

    {:noreply,
     socket
     |> assign(:show_strategy_form, true)
     |> assign(:strategy_form_tab, :ai)
     |> assign(:example_prompt, prompt)}
  end

  @impl true
  def handle_event("clear_generated_strategy", _params, socket) do
    {:noreply, assign(socket, :generated_strategy, nil)}
  end

  # ============================================================================
  # Private Functions - Data Loading
  # ============================================================================

  defp initialize_section_data(socket, nil), do: socket

  defp initialize_section_data(socket, _user) do
    socket
    |> assign(:strategies, [])
    |> assign(:simulations, [])
    |> assign(:draws, [])
    |> assign(:top_strategies, [])
    |> assign(:users, [])
    |> assign(:user_stats, %{})
    |> assign(:recent_activities, [])
    |> assign(:show_strategy_form, false)
    |> assign(:strategy_form_tab, :ai)
    |> assign(:selected_strategy, nil)
    |> assign(:target_validation_error, nil)
    |> assign(:generated_coupons, [])
    |> assign(:generated_strategy, nil)
    |> assign(:example_prompt, "")
  end

  defp load_section_data(socket, :strategies), do: load_strategies(socket)
  defp load_section_data(socket, :simulations), do: load_simulations(socket)
  defp load_section_data(socket, :ranking), do: load_ranking(socket)
  defp load_section_data(socket, :generator), do: load_generator_data(socket)
  defp load_section_data(socket, :admin), do: load_admin_data(socket)
  defp load_section_data(socket, :dashboard), do: load_dashboard_data(socket)
  defp load_section_data(socket, _), do: socket

  defp load_strategies(socket) do
    user = socket.assigns.current_user
    strategies = if user, do: Strategies.list_strategies(user), else: []
    assign(socket, :strategies, strategies)
  end

  defp load_ranking(socket) do
    user = socket.assigns.current_user

    strategies =
      if user,
        do: Strategies.list_strategies(user, sort: "performance_score", order: "desc"),
        else: []

    assign(socket, :strategies, strategies)
  end

  defp load_generator_data(socket) do
    user = socket.assigns.current_user

    top_strategies =
      if user,
        do:
          Strategies.list_strategies(user, sort: "performance_score", order: "desc")
          |> Enum.take(3),
        else: []

    assign(socket, :top_strategies, top_strategies)
  end

  defp load_admin_data(socket) do
    # Load all users, their stats, and recent activities
    users = Accounts.list_users()

    user_stats =
      Enum.map(users, fn user ->
        stats = Accounts.get_user_stats(user)
        {user.id, stats}
      end)
      |> Map.new()

    # Get recent activities (simulations, strategies created)
    recent_activities = get_recent_activities()

    socket
    |> assign(:users, users)
    |> assign(:user_stats, user_stats)
    |> assign(:recent_activities, recent_activities)
  end

  defp load_dashboard_data(socket) do
    user = socket.assigns.current_user

    if user do
      stats = Accounts.get_user_stats(user)
      recent_simulations = Simulations.list_simulations(user, limit: 5)
      strategy_pools = build_strategy_pools_map(recent_simulations)

      socket
      |> assign(:user_stats, stats)
      |> assign(:recent_simulations, recent_simulations)
      |> assign(:strategy_pools, strategy_pools)
    else
      socket
    end
  end

  defp load_simulations(socket) do
    user = socket.assigns.current_user
    strategies = if user, do: Strategies.list_strategies(user), else: []
    simulations = if user, do: Simulations.list_simulations(user), else: []
    draws = Draws.list_draws(limit: 50)
    strategy_pools = build_strategy_pools_map(simulations)

    socket
    |> assign(:strategies, strategies)
    |> assign(:simulations, simulations)
    |> assign(:draws, draws)
    |> assign(:strategy_pools, strategy_pools)
    |> assign(:selected_strategy, nil)
    |> assign(:target_validation_error, nil)
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

  defp get_initial_section(nil), do: :landing
  defp get_initial_section(_user), do: :dashboard

  # Helper functions for strategies and generator
  defp find_strategy(socket, strategy_id) do
    Enum.find(socket.assigns[:top_strategies] || [], fn s -> s.id == strategy_id end) ||
      Enum.find(socket.assigns[:strategies] || [], fn s -> s.id == strategy_id end)
  end

  # Admin helper functions
  defp admin?(user) when is_nil(user), do: false

  defp admin?(user) do
    admin_user = Application.get_env(:numbers_evolution, :admin_user, "aa@aa.aa")
    user.email == admin_user
  end

  defp get_recent_activities do
    # Get recent simulations across all users
    recent_simulations =
      from(s in NumbersEvolution.Simulations.Simulation,
        order_by: [desc: s.inserted_at],
        limit: 20,
        preload: [:user, :strategy]
      )
      |> Repo.all()

    # Get recent strategies across all users
    recent_strategies =
      from(s in NumbersEvolution.Strategies.Strategy,
        where: s.status == "active",
        order_by: [desc: s.inserted_at],
        limit: 20,
        preload: :user
      )
      |> Repo.all()

    # Combine and sort by creation date (newest first)
    (recent_simulations ++ recent_strategies)
    |> Enum.sort(fn a, b ->
      DateTime.compare(a.inserted_at, b.inserted_at) == :gt
    end)
    |> Enum.take(20)
  end

  defp build_strategy_pools_map(simulations) do
    simulations
    |> Enum.filter(fn sim ->
      Ecto.assoc_loaded?(sim.strategy) && sim.strategy != nil
    end)
    |> Enum.reduce(%{}, fn sim, acc ->
      pools = Generator.get_strategy_pools(sim.strategy)
      Map.put(acc, sim.id, pools)
    end)
  end

  defp generate_coupons_for_strategy(strategy, count) when count >= 1 and count <= 10 do
    coupons =
      1..count
      |> Enum.map(fn _ ->
        case Generator.generate_numbers(strategy) do
          {:ok, numbers} ->
            %{
              main_numbers: numbers.main,
              euro_numbers: numbers.euro
            }

          {:error, _} ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if length(coupons) == count do
      {:ok, coupons}
    else
      {:error, :generation_failed}
    end
  end

  defp generate_coupons_for_strategy(_strategy, _count), do: {:error, :invalid_count}

  defp translate_errors(changeset) do
    changeset.errors
    |> Enum.map_join(", ", fn {field, {message, _}} -> "#{field}: #{message}" end)
  end

  defp extract_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {key, errors} -> "#{key}: #{Enum.join(errors, ", ")}" end)
  end

  # ============================================================================
  # PubSub Handlers for Real-time Updates
  # ============================================================================

  @impl true
  def handle_info({:simulation_progress, simulation_id, %{attempts: attempts} = progress}, socket) do
    # Ensure simulation_id is a string for consistent map keys
    sim_id_string = to_string(simulation_id)

    # Update live attempts
    live_attempts = Map.put(socket.assigns.live_attempts || %{}, sim_id_string, attempts)

    # Update live prize tiers if available
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

    # Remove from live_attempts and live_prize_tiers and unsubscribe
    live_attempts = Map.delete(socket.assigns.live_attempts || %{}, simulation_id)
    live_prize_tiers = Map.delete(socket.assigns.live_prize_tiers || %{}, simulation_id)

    socket =
      socket
      |> assign(:live_attempts, live_attempts)
      |> assign(:live_prize_tiers, live_prize_tiers)
      |> unsubscribe_from_simulation(simulation_id)
      |> load_simulations()
      |> load_dashboard_data()

    {:noreply, socket}
  end

  # Fallback handler for unknown messages
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ============================================================================
  # PubSub Subscription Helpers
  # ============================================================================

  defp subscribe_to_running_simulations(socket, nil), do: socket

  defp subscribe_to_running_simulations(socket, user) do
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
  # Render Function - Main Template
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <.flash_group flash={@flash} />
      <%= if @current_user do %>
        <.navbar active_section={@active_section} current_user={@current_user} />

        <main class="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <%= case @active_section do %>
            <% :dashboard -> %>
              <.dashboard_section
                current_user={@current_user}
                user_stats={
                  Map.get(assigns, :user_stats) ||
                    %{strategies_count: 0, simulations_count: 0, best_strategy: nil}
                }
                recent_simulations={assigns[:recent_simulations] || []}
                live_attempts={@live_attempts}
              />
            <% :strategies -> %>
              <.strategies_section
                strategies={@strategies}
                show_strategy_form={@show_strategy_form}
                strategy_form_tab={@strategy_form_tab}
                generated_strategy={@generated_strategy}
                example_prompt={@example_prompt}
              />
            <% :simulations -> %>
              <.simulations_section
                strategies={@strategies}
                simulations={@simulations}
                draws={@draws}
                live_attempts={@live_attempts}
                live_prize_tiers={@live_prize_tiers}
                strategy_pools={assigns[:strategy_pools] || %{}}
                selected_strategy={@selected_strategy}
                target_validation_error={@target_validation_error}
              />
            <% :ranking -> %>
              <.ranking_section strategies={@strategies} />
            <% :generator -> %>
              <.generator_section
                top_strategies={assigns[:top_strategies] || []}
                generated_coupons={@generated_coupons}
              />
            <% :admin -> %>
              <.admin_section
                current_user={@current_user}
                users={assigns[:users] || []}
                user_stats={assigns[:user_stats] || %{}}
                recent_activities={assigns[:recent_activities] || []}
              />
            <% _ -> %>
              <.dashboard_section
                current_user={@current_user}
                user_stats={
                  Map.get(assigns, :user_stats) ||
                    %{strategies_count: 0, simulations_count: 0, best_strategy: nil}
                }
                recent_simulations={assigns[:recent_simulations] || []}
                live_attempts={@live_attempts}
              />
          <% end %>
        </main>

        <%!-- Update Max Attempts Modal --%>
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

        <%!-- Update Timeout Modal --%>
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

        <%!-- Restart Simulation Modal --%>
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
                    <div>
                      <strong>Tryb pół-losowy:</strong> {if @restart_simulation.options[
                                                              "half_random_mode"
                                                            ], do: "Tak", else: "Nie"}
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
                      <label class="label">
                        <span class="label-text-alt text-sm font-normal">
                          Aktualnie: {format_number(
                            @restart_simulation.options["max_attempts"] || 1_000_000
                          )}
                        </span>
                      </label>
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
                      <label class="label">
                        <span class="label-text-alt text-sm font-normal">
                          Aktualnie: {format_number(
                            @restart_simulation.options["timeout_seconds"] || 86400
                          )}s
                        </span>
                      </label>
                    </div>
                  </div>

                  <details class="collapse collapse-arrow bg-base-100">
                    <summary class="collapse-title font-medium">
                      Opcje zaawansowane
                    </summary>
                    <div class="collapse-content space-y-4">
                      <div class="form-control">
                        <label class="label cursor-pointer">
                          <input
                            type="checkbox"
                            id="restart_half_random_mode_checkbox"
                            name="half_random_mode"
                            value="true"
                            class="checkbox checkbox-primary"
                            phx-hook="HalfRandomMode"
                          />
                          <span class="label-text ml-2">Losowo pomin połowę</span>
                        </label>
                        <label class="label">
                          <span class="label-text-alt">
                            Aktualnie: {if @restart_simulation.options["half_random_mode"],
                              do: "Włączone",
                              else: "Wyłączone"}
                          </span>
                        </label>
                      </div>
                    </div>
                  </details>

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

        <%!-- Simulation Details Modal --%>
        <%= if @show_simulation_details_modal do %>
          <.simulation_details_modal simulation={@simulation_details} show={true} />
        <% end %>
      <% else %>
        <div class="min-h-screen bg-gradient-to-br from-primary/10 to-secondary/10">
          <%!-- Hero Section --%>
          <header class="hero min-h-[60vh]">
            <div class="hero-content text-center">
              <div class="max-w-2xl">
                <h1 class="text-5xl font-bold mb-4">Numbers Evolution</h1>
                <p class="text-2xl mb-8">Testuj strategie typowania Eurojackpot z pomocą AI</p>
                <div class="flex gap-4 justify-center">
                  <button
                    data-cy="register-button"
                    type="button"
                    phx-click="show_register_form"
                    class="btn btn-primary btn-lg"
                  >
                    Zarejestruj się
                  </button>
                  <button
                    data-cy="login-button"
                    type="button"
                    phx-click="show_login_form"
                    class="btn btn-secondary btn-lg"
                  >
                    Zaloguj
                  </button>
                </div>
              </div>
            </div>
          </header>

          <%!-- Registration Modal --%>
          <.modal
            :if={@show_register_form}
            data-cy="register-modal"
            id="register-modal"
            show={true}
            on_cancel={JS.push("close_auth_form")}
          >
            <:title>Rejestracja</:title>
            <.form
              data-cy="register-form"
              for={@register_form}
              id="register-form"
              phx-submit="register"
              phx-change="validate_register"
              phx-debounce="blur"
            >
              <.input
                field={@register_form[:email]}
                type="email"
                label="Email"
                required
              />
              <.input
                field={@register_form[:password]}
                type="password"
                label="Hasło"
                required
              />
              <.input
                field={@register_form[:password_confirmation]}
                type="password"
                label="Potwierdź hasło"
                required
              />
              <div class="modal-action">
                <button
                  data-cy="register-cancel"
                  type="button"
                  phx-click="close_auth_form"
                  class="btn"
                >
                  Anuluj
                </button>
                <button
                  data-cy="register-submit"
                  type="submit"
                  class="btn btn-primary"
                >
                  Zarejestruj się
                </button>
              </div>
            </.form>
          </.modal>

          <%!-- Login Modal --%>
          <.modal
            :if={@show_login_form}
            data-cy="login-modal"
            id="login-modal"
            show={true}
            on_cancel={JS.push("close_auth_form")}
          >
            <:title>Logowanie</:title>
            <.form
              data-cy="login-form"
              for={@login_form}
              id="login-form"
              phx-submit="login"
              phx-change="validate_login"
            >
              <.input
                field={@login_form[:email]}
                type="email"
                label="Email"
                required
              />
              <.input
                field={@login_form[:password]}
                type="password"
                label="Hasło"
                required
              />
              <div class="modal-action">
                <button data-cy="login-cancel" type="button" phx-click="close_auth_form" class="btn">
                  Anuluj
                </button>
                <button data-cy="login-submit" type="submit" class="btn btn-primary">
                  Zaloguj
                </button>
              </div>
            </.form>
          </.modal>

          <%!-- Features Section --%>
          <section class="container mx-auto px-4 py-16">
            <h2 class="text-3xl font-bold text-center mb-12">Główne funkcjonalności</h2>
            <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
              <.feature_card
                icon="hero-light-bulb"
                title="Tworzenie strategii"
                description="Manualnie lub przez AI"
              />
              <.feature_card
                icon="hero-chart-bar"
                title="Symulacje"
                description="Na danych historycznych"
              />
              <.feature_card icon="hero-trophy" title="Ranking" description="Skuteczność strategii" />
              <.feature_card
                icon="hero-sparkles"
                title="Generator"
                description="Propozycje na losowanie"
              />
            </div>
          </section>

          <%!-- Footer with Disclaimer --%>
          <footer class="footer footer-center p-10 bg-base-200 text-base-content">
            <div class="max-w-3xl">
              <p class="text-sm">
                <strong>Disclaimer:</strong>
                Aplikacja służy wyłącznie celom edukacyjnym i symulacyjnym.
                Nie gwarantuje wygranej i nie jest oficjalnie powiązana z operatorami loterii.
              </p>
            </div>
          </footer>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Private Helpers - Simulation Validation
  # ============================================================================

  @doc """
  Validates if target draw numbers exist in strategy pools.

  Returns :ok if all target numbers are available in strategy pools,
  or {:error, reason} with suggestion to reset strategy.
  """
  @spec validate_target_in_strategy_pools(Draw.t(), map()) :: :ok | {:error, String.t()}
  def validate_target_in_strategy_pools(target_draw, strategy_pools) do
    main_target = target_draw.numbers.main_numbers
    euro_target = target_draw.numbers.euro_numbers

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
  # Admin Section
  # ============================================================================

  @doc """
  Renders the admin dashboard with user overview and activities.
  """
  attr(:current_user, :map, required: true)
  attr(:users, :list, required: true)
  attr(:user_stats, :map, required: true)
  attr(:recent_activities, :list, required: true)

  def admin_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center gap-4">
        <h1 class="text-4xl font-bold">Panel Administratora</h1>
        <.badge variant="success" size="lg">Admin: {@current_user.email}</.badge>
      </div>

      <%!-- User Statistics Overview --%>
      <.card>
        <:title>Podsumowanie użytkowników</:title>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="stat">
            <div class="stat-title">Liczba użytkowników</div>
            <div class="stat-value text-primary">{length(@users)}</div>
          </div>
          <div class="stat">
            <div class="stat-title">Razem strategii</div>
            <div class="stat-value text-secondary">
              {Enum.sum(Enum.map(@user_stats, fn {_id, stats} -> stats.strategies_count end))}
            </div>
          </div>
          <div class="stat">
            <div class="stat-title">Razem symulacji</div>
            <div class="stat-value text-accent">
              {Enum.sum(Enum.map(@user_stats, fn {_id, stats} -> stats.simulations_count end))}
            </div>
          </div>
        </div>
      </.card>

      <%!-- Users Table --%>
      <.card>
        <:title>Wszyscy użytkownicy</:title>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Email</th>
                <th>Data rejestracji</th>
                <th>Strategii</th>
                <th>Symulacji</th>
                <th>Najlepsza strategia</th>
              </tr>
            </thead>
            <tbody>
              <%= for user <- @users do %>
                <tr>
                  <td class="font-medium">{user.email}</td>
                  <td>{Calendar.strftime(user.inserted_at, "%Y-%m-%d %H:%M")}</td>
                  <td>{Map.get(@user_stats, user.id, %{strategies_count: 0}).strategies_count}</td>
                  <td>{Map.get(@user_stats, user.id, %{simulations_count: 0}).simulations_count}</td>
                  <td>
                    <%= if best = Map.get(@user_stats, user.id, %{best_strategy: nil}).best_strategy do %>
                      {best.name} ({Float.round(best.performance_score || 0, 2)})
                    <% else %>
                      Brak
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </.card>

      <%!-- Recent Activities --%>
      <.card>
        <:title>Ostatnie aktywności</:title>
        <div class="space-y-3">
          <%= for activity <- @recent_activities do %>
            <div class="flex items-center gap-3 p-3 bg-base-200 rounded-lg">
              <div class="flex-shrink-0">
                <%= if Map.has_key?(activity, :name) do %>
                  <.icon name="hero-light-bulb" class="size-5 text-warning" />
                <% else %>
                  <.icon name="hero-chart-bar" class="size-5 text-info" />
                <% end %>
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span class="font-medium">
                    <%= cond do %>
                      <% Map.has_key?(activity, :name) -> %>
                        Strategia: {activity.name}
                      <% Ecto.assoc_loaded?(activity.strategy) -> %>
                        Symulacja: {activity.strategy.name}
                      <% true -> %>
                        Symulacja
                    <% end %>
                  </span>
                  <span class="text-sm text-base-content/60">
                    {activity.user.email}
                  </span>
                </div>
                <div class="text-sm text-base-content/70">
                  {Calendar.strftime(activity.inserted_at, "%Y-%m-%d %H:%M")}
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </.card>
    </div>
    """
  end

  # ============================================================================
  # Private Helpers - Feature Card Component
  # ============================================================================

  attr(:icon, :string, required: true)
  attr(:title, :string, required: true)
  attr(:description, :string, required: true)

  defp feature_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body items-center text-center">
        <.icon name={@icon} class="size-12 text-primary mb-4" />
        <h3 class="card-title">{@title}</h3>
        <p>{@description}</p>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Private Helpers - Utility Functions
  # ============================================================================

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  defp format_number(number), do: to_string(number)
end
