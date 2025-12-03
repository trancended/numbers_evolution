defmodule NumbersEvolutionWeb.RankingLive do
  @moduledoc """
  LiveView for strategy rankings - displays performance-sorted strategies.
  """
  use NumbersEvolutionWeb, :live_view

  alias NumbersEvolution.{Accounts, Strategies}

  import NumbersEvolutionWeb.RankingComponents

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
        |> assign(:page_title, "Ranking - Numbers Evolution")
        |> assign(:active_section, :ranking)
        |> load_ranking()

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
  # Private Functions - Data Loading
  # ============================================================================

  defp load_ranking(socket) do
    user = socket.assigns.current_user

    strategies =
      if user,
        do: Strategies.list_strategies(user, sort: "performance_score", order: "desc"),
        else: []

    assign(socket, :strategies, strategies)
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
  # Render Function
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_scope={:ranking}>
      <main class="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <.ranking_section strategies={@strategies} />
      </main>
    </Layouts.app>
    """
  end
end
