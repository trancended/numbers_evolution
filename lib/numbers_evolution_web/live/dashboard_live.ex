defmodule NumbersEvolutionWeb.DashboardLive do
  @moduledoc """
  LiveView for user dashboard - shows statistics and recent activity.
  """
  use NumbersEvolutionWeb, :live_view

  alias NumbersEvolution.{Accounts, Simulations}
  alias NumbersEvolution.Strategies.Generator

  import NumbersEvolutionWeb.DashboardComponents

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
        |> assign(:page_title, "Dashboard - Numbers Evolution")
        |> assign(:live_attempts, %{})
        |> assign(:active_section, :dashboard)
        |> load_dashboard_data()
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
  # Event Handlers
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
  # PubSub Handlers for Real-time Updates
  # ============================================================================

  @impl true
  def handle_info({:simulation_progress, simulation_id, %{attempts: attempts}}, socket) do
    sim_id_string = to_string(simulation_id)
    live_attempts = Map.put(socket.assigns.live_attempts || %{}, sim_id_string, attempts)

    {:noreply, assign(socket, live_attempts: live_attempts)}
  end

  @impl true
  def handle_info({:simulation_complete, simulation}, socket) do
    simulation_id = simulation.id
    live_attempts = Map.delete(socket.assigns.live_attempts || %{}, simulation_id)

    socket =
      socket
      |> assign(:live_attempts, live_attempts)
      |> unsubscribe_from_simulation(simulation_id)
      |> load_dashboard_data()

    {:noreply, socket}
  end

  # Fallback handler for unknown messages
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ============================================================================
  # Private Functions - Data Loading
  # ============================================================================

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
    <Layouts.app flash={@flash} current_user={@current_user} current_scope={:dashboard}>
      <main class="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <.dashboard_section
          current_user={@current_user}
          user_stats={@user_stats}
          recent_simulations={@recent_simulations}
          live_attempts={@live_attempts}
        />
      </main>
    </Layouts.app>
    """
  end
end
