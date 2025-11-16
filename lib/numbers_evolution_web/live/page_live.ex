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

  alias NumbersEvolution.{Accounts, Draws, Simulations, Strategies}

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
      |> assign(:register_form, to_form(%{}, as: :user))
      |> assign(:login_form, to_form(%{}, as: :user))
      |> initialize_section_data(current_user)
      |> load_dashboard_data_if_user(current_user)

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

    socket =
      socket
      |> assign(:active_section, section_atom)
      |> load_section_data(section_atom)

    {:noreply, socket}
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
    changeset =
      %Accounts.User{}
      |> Accounts.User.registration_changeset(user_params)
      |> Map.put(:action, :validate)

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

    try do
      case Strategies.delete_strategy(user, id) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Strategia została usunięta")
           |> load_strategies()}
      end
    rescue
      Ecto.NoResultsError ->
        {:noreply, put_flash(socket, :error, "Nie znaleziono strategii")}
    end
  end

  @impl true
  def handle_event("toggle_strategy_select", %{"id" => id}, socket) do
    selected = socket.assigns.selected_strategies

    new_selected =
      if id in selected do
        List.delete(selected, id)
      else
        [id | selected]
      end

    {:noreply, assign(socket, :selected_strategies, new_selected)}
  end

  # Simulations section events
  @impl true
  def handle_event("start_simulation", params, socket) do
    user = socket.assigns.current_user

    case Simulations.start_simulation(user, params) do
      {:ok, _simulation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Symulacja została uruchomiona w tle")
         |> load_simulations()}

      {:error, :strategy_not_found} ->
        {:noreply, put_flash(socket, :error, "Nie znaleziono strategii")}

      {:error, :draw_not_found} ->
        {:noreply, put_flash(socket, :error, "Nie znaleziono losowania")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Nie udało się uruchomić symulacji")}
    end
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
  def handle_event("use_example_prompt", %{"prompt" => prompt}, socket) do
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
    |> assign(:show_strategy_form, false)
    |> assign(:strategy_form_tab, :ai)
    |> assign(:selected_strategies, [])
    |> assign(:generated_coupons, [])
    |> assign(:generated_strategy, nil)
    |> assign(:example_prompt, "")
  end

  defp load_section_data(socket, :strategies), do: load_strategies(socket)
  defp load_section_data(socket, :simulations), do: load_simulations(socket)
  defp load_section_data(socket, :ranking), do: load_ranking(socket)
  defp load_section_data(socket, :generator), do: load_generator_data(socket)
  defp load_section_data(socket, :dashboard), do: load_dashboard_data(socket)
  defp load_section_data(socket, _), do: socket

  defp load_strategies(socket) do
    user = socket.assigns.current_user
    strategies = if user, do: Strategies.list_strategies(user), else: []
    assign(socket, :strategies, strategies)
  end

  defp load_simulations(socket) do
    user = socket.assigns.current_user
    simulations = if user, do: Simulations.list_simulations(user), else: []
    draws = Draws.list_draws(limit: 50)

    socket
    |> assign(:simulations, simulations)
    |> assign(:draws, draws)
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

  defp load_dashboard_data(socket) do
    user = socket.assigns.current_user

    if user do
      stats = Accounts.get_user_stats(user)
      recent_simulations = Simulations.list_simulations(user, limit: 5)

      socket
      |> assign(:user_stats, stats)
      |> assign(:recent_simulations, recent_simulations)
    else
      socket
    end
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

  defp generate_coupons_for_strategy(strategy, count) when count >= 1 and count <= 10 do
    coupons =
      1..count
      |> Enum.map(fn _ ->
        case NumbersEvolution.Strategies.Generator.generate_numbers(strategy) do
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

  defp extract_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {key, errors} -> "#{key}: #{Enum.join(errors, ", ")}" end)
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
              />
            <% :strategies -> %>
              <.strategies_section
                strategies={@strategies}
                selected_strategies={@selected_strategies}
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
              />
            <% :ranking -> %>
              <.ranking_section strategies={@strategies} />
            <% :generator -> %>
              <.generator_section
                top_strategies={assigns[:top_strategies] || []}
                generated_coupons={@generated_coupons}
              />
            <% _ -> %>
              <.dashboard_section
                current_user={@current_user}
                user_stats={
                  Map.get(assigns, :user_stats) ||
                    %{strategies_count: 0, simulations_count: 0, best_strategy: nil}
                }
                recent_simulations={assigns[:recent_simulations] || []}
              />
          <% end %>
        </main>
      <% else %>
        <.landing_section
          show_register_form={@show_register_form}
          show_login_form={@show_login_form}
          form={if @show_register_form, do: @register_form, else: @login_form}
        />
      <% end %>
    </div>
    """
  end
end
