defmodule NumbersEvolutionWeb.AdminLive do
  @moduledoc """
  LiveView for admin panel - user management and system overview.
  """
  use NumbersEvolutionWeb, :live_view

  alias NumbersEvolution.{Accounts, Repo, Simulations, Strategies}

  import Ecto.Query

  # ============================================================================
  # LiveView Callbacks
  # ============================================================================

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    if current_user && admin?(current_user) do
      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:page_title, "Admin - Numbers Evolution")
        |> assign(:active_section, :admin)
        |> load_admin_data()

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "Brak dostępu do panelu administratora")
       |> redirect(to: "/dashboard")}
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
  # Private Functions - Data Loading
  # ============================================================================

  defp load_admin_data(socket) do
    users = Accounts.list_users()

    user_stats =
      Enum.map(users, fn user ->
        stats = Accounts.get_user_stats(user)
        {user.id, stats}
      end)
      |> Map.new()

    recent_activities = get_recent_activities()

    socket
    |> assign(:users, users)
    |> assign(:user_stats, user_stats)
    |> assign(:recent_activities, recent_activities)
  end

  defp get_recent_activities do
    # Get recent simulations across all users
    recent_simulations =
      from(s in Simulations.Simulation,
        order_by: [desc: s.inserted_at],
        limit: 20,
        preload: [:user, :strategy]
      )
      |> Repo.all()

    # Get recent strategies across all users
    recent_strategies =
      from(s in Strategies.Strategy,
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

  defp admin?(user) when is_nil(user), do: false

  defp admin?(user) do
    admin_user = Application.get_env(:numbers_evolution, :admin_user, "aa@aa.aa")
    user.email == admin_user
  end

  # ============================================================================
  # Render Function
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <NumbersEvolutionWeb.Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_scope={:admin}
    >
      <main class="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
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
                      <td>
                        {Map.get(@user_stats, user.id, %{strategies_count: 0}).strategies_count}
                      </td>
                      <td>
                        {Map.get(@user_stats, user.id, %{simulations_count: 0}).simulations_count}
                      </td>
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
      </main>
    </NumbersEvolutionWeb.Layouts.app>
    """
  end
end
