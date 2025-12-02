defmodule NumbersEvolutionWeb.GeneratorLive do
  @moduledoc """
  LiveView for coupon generator - generates lottery coupons based on top strategies.
  """
  use NumbersEvolutionWeb, :live_view

  alias NumbersEvolution.{Accounts, Strategies}
  alias NumbersEvolution.Strategies.Generator

  import NumbersEvolutionWeb.GeneratorComponents

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
        |> assign(:page_title, "Generator - Numbers Evolution")
        |> assign(:active_section, :generator)
        |> assign(:generated_coupons, [])
        |> assign(:selected_strategy_id, nil)
        |> assign(:coupons_count, 3)
        |> load_generator_data()

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

  # ============================================================================
  # Private Functions - Data Loading
  # ============================================================================

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

  # ============================================================================
  # Private Functions - Generator Helpers
  # ============================================================================

  defp find_strategy(socket, strategy_id) do
    Enum.find(socket.assigns[:top_strategies] || [], fn s -> s.id == strategy_id end)
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
    <Layouts.app flash={@flash} current_user={@current_user} current_scope={:generator}>
      <main class="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <.generator_section
          top_strategies={@top_strategies}
          generated_coupons={@generated_coupons}
        />
      </main>
    </Layouts.app>
    """
  end
end
