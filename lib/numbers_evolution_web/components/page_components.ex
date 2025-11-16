defmodule NumbersEvolutionWeb.PageComponents do
  @moduledoc """
  Function components for page sections in Numbers Evolution SPA.
  Each section is a stateless component that receives assigns from PageLive.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents

  # ============================================================================
  # Navigation Component
  # ============================================================================

  @doc """
  Renders the main navigation bar (desktop) and drawer (mobile).
  """
  attr :active_section, :atom, required: true
  attr :current_user, :map, required: true

  def navbar(assigns) do
    ~H"""
    <%!-- Desktop Navbar (>768px) --%>
    <nav class="navbar bg-base-200 px-4 sm:px-6 lg:px-8 shadow-lg hidden md:flex">
      <div class="flex-1">
        <span class="text-xl font-bold">Numbers Evolution</span>
      </div>
      <div class="flex-none">
        <ul class="menu menu-horizontal px-1 gap-2">
          <li>
            <button
              phx-click="navigate"
              phx-value-section="dashboard"
              class={["btn btn-ghost", @active_section == :dashboard && "btn-active"]}
            >
              <.icon name="hero-home" class="size-5" /> Dashboard
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="strategies"
              class={["btn btn-ghost", @active_section == :strategies && "btn-active"]}
            >
              <.icon name="hero-light-bulb" class="size-5" /> Strategie
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="simulations"
              class={["btn btn-ghost", @active_section == :simulations && "btn-active"]}
            >
              <.icon name="hero-chart-bar" class="size-5" /> Symulacje
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="ranking"
              class={["btn btn-ghost", @active_section == :ranking && "btn-active"]}
            >
              <.icon name="hero-trophy" class="size-5" /> Ranking
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="generator"
              class={["btn btn-ghost", @active_section == :generator && "btn-active"]}
            >
              <.icon name="hero-sparkles" class="size-5" /> Generator
            </button>
          </li>
          <li>
            <div class="dropdown dropdown-end">
              <label tabindex="0" class="btn btn-ghost">
                <.icon name="hero-user-circle" class="size-5" />
                {@current_user.email}
              </label>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52 mt-2"
              >
                <li>
                  <button phx-click="logout" class="w-full text-left">Wyloguj</button>
                </li>
              </ul>
            </div>
          </li>
        </ul>
      </div>
    </nav>

    <%!-- Mobile Drawer (≤768px) --%>
    <div class="drawer md:hidden">
      <input id="mobile-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content">
        <nav class="navbar bg-base-200 px-4 shadow-lg">
          <div class="flex-1">
            <label for="mobile-drawer" class="btn btn-ghost btn-circle">
              <.icon name="hero-bars-3" class="size-6" />
            </label>
            <span class="ml-2 text-lg font-bold">Numbers Evolution</span>
          </div>
        </nav>
      </div>
      <div class="drawer-side z-50">
        <label for="mobile-drawer" class="drawer-overlay"></label>
        <ul class="menu p-4 w-80 min-h-full bg-base-200 gap-2">
          <li class="mb-4">
            <span class="text-xl font-bold">Numbers Evolution</span>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="dashboard"
              class={["btn btn-ghost justify-start", @active_section == :dashboard && "btn-active"]}
            >
              <.icon name="hero-home" class="size-5" /> Dashboard
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="strategies"
              class={["btn btn-ghost justify-start", @active_section == :strategies && "btn-active"]}
            >
              <.icon name="hero-light-bulb" class="size-5" /> Strategie
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="simulations"
              class={["btn btn-ghost justify-start", @active_section == :simulations && "btn-active"]}
            >
              <.icon name="hero-chart-bar" class="size-5" /> Symulacje
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="ranking"
              class={["btn btn-ghost justify-start", @active_section == :ranking && "btn-active"]}
            >
              <.icon name="hero-trophy" class="size-5" /> Ranking
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="generator"
              class={["btn btn-ghost justify-start", @active_section == :generator && "btn-active"]}
            >
              <.icon name="hero-sparkles" class="size-5" /> Generator
            </button>
          </li>
          <li class="mt-auto">
            <div class="border-t border-base-300 pt-4">
              <p class="text-sm mb-2">{@current_user.email}</p>
              <button phx-click="logout" class="btn btn-error btn-sm w-full">Wyloguj</button>
            </div>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Landing Section
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
      <header class="hero min-h-[60vh]">
        <div class="hero-content text-center">
          <div class="max-w-2xl">
            <h1 class="text-5xl font-bold mb-4">Numbers Evolution</h1>
            <p class="text-2xl mb-8">Testuj strategie typowania Eurojackpot z pomocą AI</p>
            <div class="flex gap-4 justify-center">
              <button
                phx-click="show_register_form"
                class="btn btn-primary btn-lg"
              >
                Zarejestruj się
              </button>
              <button
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
      <%= if @show_register_form do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Rejestracja</h3>
            <.form
              for={@form}
              id="register-form"
              phx-submit="register"
              phx-change="validate_register"
            >
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                required
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Hasło"
                required
              />
              <.input
                field={@form[:password_confirmation]}
                type="password"
                label="Potwierdź hasło"
                required
              />
              <div class="modal-action">
                <button type="button" phx-click="close_auth_form" class="btn">
                  Anuluj
                </button>
                <button type="submit" class="btn btn-primary">
                  Zarejestruj się
                </button>
              </div>
            </.form>
          </div>
          <form method="dialog" class="modal-backdrop">
            <button phx-click="close_auth_form">zamknij</button>
          </form>
        </div>
      <% end %>

      <%!-- Login Modal --%>
      <%= if @show_login_form do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Logowanie</h3>
            <.form
              for={@form}
              id="login-form"
              phx-submit="login"
              phx-change="validate_login"
            >
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                required
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Hasło"
                required
              />
              <div class="modal-action">
                <button type="button" phx-click="close_auth_form" class="btn">
                  Anuluj
                </button>
                <button type="submit" class="btn btn-primary">
                  Zaloguj
                </button>
              </div>
            </.form>
          </div>
          <form method="dialog" class="modal-backdrop">
            <button phx-click="close_auth_form">zamknij</button>
          </form>
        </div>
      <% end %>

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

  # ============================================================================
  # Dashboard Section
  # ============================================================================

  @doc """
  Renders the dashboard with user stats and quick actions.
  """
  attr :current_user, :map, required: true

  attr :user_stats, :map,
    default: %{strategies_count: 0, simulations_count: 0, best_strategy: nil}

  attr :recent_simulations, :list, default: []

  def dashboard_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <h1 class="text-4xl font-bold">Dashboard</h1>
      <p class="text-lg">Witaj, {@current_user.email}</p>

      <%!-- Stats Cards --%>
      <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
        <.stat_card
          icon="hero-light-bulb"
          title="Strategie"
          value={to_string(Map.get(@user_stats, :strategies_count, 0))}
        />
        <.stat_card
          icon="hero-chart-bar"
          title="Symulacje"
          value={to_string(Map.get(@user_stats, :simulations_count, 0))}
        />
        <.stat_card
          icon="hero-trophy"
          title="Najlepsza"
          value={
            if best_strategy = Map.get(@user_stats, :best_strategy), do: best_strategy.name, else: "—"
          }
        />
        <.stat_card icon="hero-calendar" title="Ostatnia aktywność" value="Dzisiaj" />
      </div>

      <%!-- Quick Actions --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <h2 class="card-title">Szybkie akcje</h2>
          <div class="grid md:grid-cols-3 gap-4 mt-4">
            <button
              phx-click="navigate"
              phx-value-section="strategies"
              class="btn btn-primary btn-lg"
            >
              <.icon name="hero-plus-circle" class="size-6" /> Utwórz nową strategię
            </button>
            <button
              phx-click="navigate"
              phx-value-section="simulations"
              class="btn btn-primary btn-lg"
            >
              <.icon name="hero-play" class="size-6" /> Uruchom symulację
            </button>
            <button
              phx-click="navigate"
              phx-value-section="generator"
              class="btn btn-primary btn-lg"
            >
              <.icon name="hero-sparkles" class="size-6" /> Generuj propozycje
            </button>
          </div>
        </div>
      </div>

      <%!-- Recent Simulations --%>
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Ostatnie symulacje</h2>
          <%= if @recent_simulations == [] do %>
            <div class="text-center py-8 text-base-content/60">
              <.icon name="hero-chart-bar" class="size-16 mx-auto mb-4 opacity-30" />
              <p>Nie masz jeszcze żadnych symulacji</p>
              <button
                phx-click="navigate"
                phx-value-section="simulations"
                class="btn btn-primary mt-4"
              >
                Uruchom pierwszą symulację
              </button>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>Strategia</th>
                    <th>Data</th>
                    <th>Próby</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for sim <- @recent_simulations do %>
                    <tr>
                      <td>{sim.strategy_id}</td>
                      <td>{Calendar.strftime(sim.inserted_at, "%Y-%m-%d %H:%M")}</td>
                      <td>{(sim.result && sim.result["attempts_count"]) || "—"}</td>
                      <td>
                        <.status_indicator status={sim.status} />
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :value, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="stats shadow">
      <div class="stat">
        <div class="stat-figure text-primary">
          <.icon name={@icon} class="size-8" />
        </div>
        <div class="stat-title">{@title}</div>
        <div class="stat-value text-primary">{@value}</div>
      </div>
    </div>
    """
  end
end
