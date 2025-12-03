defmodule NumbersEvolutionWeb.PageLive do
  @moduledoc """
  Landing page LiveView for Numbers Evolution.
  Handles authentication (login/register) and redirects authenticated users to dashboard.
  """
  use NumbersEvolutionWeb, :live_view

  alias NumbersEvolution.Accounts

  import NumbersEvolutionWeb.CoreComponents
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
      |> assign(:page_title, "Numbers Evolution")
      |> assign(:show_register_form, false)
      |> assign(:show_login_form, false)
      |> assign(:register_form, to_form(%{}, as: :user))
      |> assign(:login_form, to_form(%{}, as: :user))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      cond do
        # Handle logout
        Map.get(params, "logout") == "true" ->
          handle_logout_params(socket)

        # Handle token-based login
        token = Map.get(params, "token") ->
          verify_and_login_with_token(socket, token)

        # Check if user is already authenticated
        socket.assigns.current_user != nil ->
          push_navigate(socket, to: "/dashboard")

        # Default case - show landing page
        true ->
          socket
      end

    {:noreply, socket}
  end

  defp handle_logout_params(socket) do
    socket
    |> assign(:current_user, nil)
    |> push_patch(to: "/", replace: true)
  end

  defp verify_and_login_with_token(socket, token) when is_binary(token) do
    case Accounts.verify_user_token(token) do
      {:ok, user} ->
        socket
        |> assign(:current_user, user)
        |> push_navigate(to: "/dashboard")

      {:error, _} ->
        socket
    end
  end

  # ============================================================================
  # Event Handlers - Authentication Forms
  # ============================================================================

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
         |> assign(:show_register_form, false)
         |> assign(:show_login_form, false)
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
         |> assign(:show_register_form, false)
         |> assign(:show_login_form, false)
         |> redirect(to: "/?token=#{token}")}

      {:error, :invalid_credentials} ->
        {:noreply,
         socket
         |> put_flash(:error, "Nieprawidłowy email lub hasło")
         |> assign(:show_login_form, true)}
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

  # ============================================================================
  # Render Function
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-primary/10 to-secondary/10">
      <.flash_group flash={@flash} />

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
          <.input field={@register_form[:email]} type="email" label="Email" required />
          <.input field={@register_form[:password]} type="password" label="Hasło" required />
          <.input
            field={@register_form[:password_confirmation]}
            type="password"
            label="Potwierdź hasło"
            required
          />
          <div class="modal-action">
            <button data-cy="register-cancel" type="button" phx-click="close_auth_form" class="btn">
              Anuluj
            </button>
            <button data-cy="register-submit" type="submit" class="btn btn-primary">
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
          <.input field={@login_form[:email]} type="email" label="Email" required />
          <.input field={@login_form[:password]} type="password" label="Hasło" required />
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
            <strong>Disclaimer:</strong> Aplikacja służy wyłącznie celom edukacyjnym i symulacyjnym.
            Nie gwarantuje wygranej i nie jest oficjalnie powiązana z operatorami loterii.
          </p>
        </div>
      </footer>
    </div>
    """
  end

  # ============================================================================
  # Private Components - Feature Card
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
end
