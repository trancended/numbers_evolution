defmodule NumbersEvolutionWeb.LandingComponents do
  @moduledoc """
  Components for the landing page (unauthenticated users).
  Includes hero section, features, authentication modals.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents

  alias Phoenix.LiveView.JS

  # ============================================================================
  # Main Landing Section
  # ============================================================================

  @doc """
  Renders the landing page for unauthenticated users.
  """
  attr :show_register_form, :boolean, default: false
  attr :show_login_form, :boolean, default: false
  attr :form, :map, default: nil

  def landing_section(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-primary/10 to-secondary/10">
      <%!-- Hero Section --%>
      <.hero_section />

      <%!-- Registration Modal --%>
      <.registration_modal show={@show_register_form} form={@form} />

      <%!-- Login Modal --%>
      <.login_modal show={@show_login_form} form={@form} />

      <%!-- Features Section --%>
      <.features_section />

      <%!-- Footer with Disclaimer --%>
      <.footer_section />
    </div>
    """
  end

  # ============================================================================
  # Private Components
  # ============================================================================

  defp hero_section(assigns) do
    ~H"""
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
    """
  end

  attr :show, :boolean, required: true
  attr :form, :map, required: true

  defp registration_modal(assigns) do
    ~H"""
    <.modal
      :if={@show}
      data-cy="register-modal"
      id="register-modal"
      show={true}
      on_cancel={JS.push("close_auth_form")}
    >
      <:title>Rejestracja</:title>
      <.form
        data-cy="register-form"
        for={@form}
        id="register-form"
        phx-submit="register"
        phx-change="validate_register"
      >
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Hasło" required />
        <.input
          field={@form[:password_confirmation]}
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
    """
  end

  attr :show, :boolean, required: true
  attr :form, :map, required: true

  defp login_modal(assigns) do
    ~H"""
    <.modal
      :if={@show}
      data-cy="login-modal"
      id="login-modal"
      show={true}
      on_cancel={JS.push("close_auth_form")}
    >
      <:title>Logowanie</:title>
      <.form
        data-cy="login-form"
        for={@form}
        id="login-form"
        phx-submit="login"
        phx-change="validate_login"
      >
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Hasło" required />
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
    """
  end

  defp features_section(assigns) do
    ~H"""
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
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

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

  defp footer_section(assigns) do
    ~H"""
    <footer class="footer footer-center p-10 bg-base-200 text-base-content">
      <div class="max-w-3xl">
        <p class="text-sm">
          <strong>Disclaimer:</strong> Aplikacja służy wyłącznie celom edukacyjnym i symulacyjnym.
          Nie gwarantuje wygranej i nie jest oficjalnie powiązana z operatorami loterii.
        </p>
      </div>
    </footer>
    """
  end
end
