defmodule NumbersEvolutionWeb.StrategiesLive do
  @moduledoc """
  LiveView for strategy management - create, edit, and delete strategies.
  """
  use NumbersEvolutionWeb, :live_view

  alias NumbersEvolution.{Accounts, Strategies}

  import NumbersEvolutionWeb.StrategyComponents

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
        |> assign(:page_title, "Strategie - Numbers Evolution")
        |> assign(:active_section, :strategies)
        |> assign(:show_strategy_form, false)
        |> assign(:strategy_form_tab, :ai)
        |> assign(:generated_strategy, nil)
        |> assign(:example_prompt, "")
        |> load_strategies()

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
  # Event Handlers - Strategy Form
  # ============================================================================

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

  # ============================================================================
  # Event Handlers - AI Strategy Generation
  # ============================================================================

  @impl true
  def handle_event("create_ai_strategy", %{"prompt" => prompt}, socket) do
    user = socket.assigns.current_user

    case Strategies.create_ai_strategy(user, prompt) do
      {:ok, strategy} ->
        # Broadcast strategy creation
        Phoenix.PubSub.broadcast(
          NumbersEvolution.PubSub,
          "user:#{user.id}",
          {:strategy_created, strategy}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Strategia '#{strategy.name}' została wygenerowana przez AI!")
         |> assign(:show_strategy_form, false)
         |> assign(:generated_strategy, nil)
         |> load_strategies()}

      {:error, :prompt_too_short} ->
        {:noreply, put_flash(socket, :error, "Prompt musi mieć minimum 10 znaków")}

      {:error, :prompt_too_long} ->
        {:noreply, put_flash(socket, :error, "Prompt nie może przekraczać 1000 znaków")}

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
  # Event Handlers - Strategy Management
  # ============================================================================

  @impl true
  def handle_event("delete_strategy", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Strategies.delete_strategy(user, id) do
      {:ok, strategy} ->
        # Broadcast strategy deletion
        Phoenix.PubSub.broadcast(
          NumbersEvolution.PubSub,
          "user:#{user.id}",
          {:strategy_deleted, strategy}
        )

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

  # ============================================================================
  # PubSub Handlers
  # ============================================================================

  @impl true
  def handle_info({:strategy_created, _strategy}, socket) do
    {:noreply, load_strategies(socket)}
  end

  @impl true
  def handle_info({:strategy_deleted, _strategy}, socket) do
    {:noreply, load_strategies(socket)}
  end

  # Fallback handler for unknown messages
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ============================================================================
  # Private Functions - Data Loading
  # ============================================================================

  defp load_strategies(socket) do
    user = socket.assigns.current_user
    strategies = if user, do: Strategies.list_strategies(user), else: []
    assign(socket, :strategies, strategies)
  end

  # ============================================================================
  # Private Functions - Utilities
  # ============================================================================

  defp extract_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {key, errors} -> "#{key}: #{Enum.join(errors, ", ")}" end)
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
    <Layouts.app flash={@flash} current_user={@current_user} current_scope={:strategies}>
      <main class="container mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <.strategies_section
          strategies={@strategies}
          show_strategy_form={@show_strategy_form}
          strategy_form_tab={@strategy_form_tab}
          generated_strategy={@generated_strategy}
          example_prompt={@example_prompt}
        />
      </main>
    </Layouts.app>
    """
  end
end
