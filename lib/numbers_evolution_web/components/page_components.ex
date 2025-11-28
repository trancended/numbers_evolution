defmodule NumbersEvolutionWeb.PageComponents do
  @moduledoc """
  Function components for page sections in Numbers Evolution SPA.
  Each section is a stateless component that receives assigns from PageLive.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents

  alias Phoenix.LiveView.JS

  # Admin helper functions
  defp admin?(user) when is_nil(user), do: false

  defp admin?(user) do
    admin_user = Application.get_env(:numbers_evolution, :admin_user, "aa@aa.aa")
    user.email == admin_user
  end

  # ============================================================================
  # Navigation Component
  # ============================================================================

  @doc """
  Renders the main navigation bar (desktop) and drawer (mobile).
  """
  attr(:active_section, :atom, required: true)
  attr(:current_user, :map, required: true)

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
              data-cy="nav-dashboard"
              phx-click="navigate"
              phx-value-section="dashboard"
              class={["btn btn-ghost", @active_section == :dashboard && "btn-active"]}
            >
              <.icon name="hero-home" class="size-5 mr-2" /> Dashboard
            </button>
          </li>
          <li>
            <button
              data-cy="nav-strategies"
              phx-click="navigate"
              phx-value-section="strategies"
              class={["btn btn-ghost", @active_section == :strategies && "btn-active"]}
            >
              <.icon name="hero-light-bulb" class="size-5 mr-2" /> Strategie
            </button>
          </li>
          <li>
            <button
              data-cy="nav-simulations"
              phx-click="navigate"
              phx-value-section="simulations"
              class={["btn btn-ghost", @active_section == :simulations && "btn-active"]}
            >
              <.icon name="hero-chart-bar" class="size-5 mr-2" /> Symulacje
            </button>
          </li>
          <li>
            <button
              data-cy="nav-ranking"
              phx-click="navigate"
              phx-value-section="ranking"
              class={["btn btn-ghost", @active_section == :ranking && "btn-active"]}
            >
              <.icon name="hero-trophy" class="size-5 mr-2" /> Ranking
            </button>
          </li>
          <li>
            <button
              data-cy="nav-generator"
              phx-click="navigate"
              phx-value-section="generator"
              class={["btn btn-ghost", @active_section == :generator && "btn-active"]}
            >
              <.icon name="hero-sparkles" class="size-5 mr-2" /> Generator
            </button>
          </li>
          <%= if @current_user && admin?(@current_user) do %>
            <li>
              <button
                data-cy="nav-admin"
                phx-click="navigate"
                phx-value-section="admin"
                class={["btn btn-ghost", @active_section == :admin && "btn-active"]}
              >
                <.icon name="hero-users" class="size-5 mr-2" /> Użytkownicy
              </button>
            </li>
          <% end %>
          <li>
            <div class="dropdown dropdown-end">
              <label data-cy="user-menu" tabindex="0" class="btn btn-ghost gap-2">
                <.icon name="hero-user-circle" class="size-5" />
                <span class="hidden sm:inline">{@current_user.email}</span>
              </label>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow-lg bg-base-100 border border-base-300 rounded-box w-52 mt-2 z-50"
              >
                <li>
                  <div class="px-3 py-2 text-sm text-base-content/70 border-b border-base-300">
                    {@current_user.email}
                  </div>
                </li>
                <li>
                  <button
                    data-cy="logout-button"
                    phx-click="logout"
                    class="w-full text-left px-3 py-2 hover:bg-base-200 rounded transition-colors text-base-content"
                  >
                    <.icon name="hero-arrow-right-on-rectangle" class="size-4 inline mr-2" /> Wyloguj
                  </button>
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
              <.icon name="hero-home" class="size-5 mr-2" /> Dashboard
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="strategies"
              class={["btn btn-ghost justify-start", @active_section == :strategies && "btn-active"]}
            >
              <.icon name="hero-light-bulb" class="size-5 mr-2" /> Strategie
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="simulations"
              class={["btn btn-ghost justify-start", @active_section == :simulations && "btn-active"]}
            >
              <.icon name="hero-chart-bar" class="size-5 mr-2" /> Symulacje
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="ranking"
              class={["btn btn-ghost justify-start", @active_section == :ranking && "btn-active"]}
            >
              <.icon name="hero-trophy" class="size-5 mr-2" /> Ranking
            </button>
          </li>
          <li>
            <button
              phx-click="navigate"
              phx-value-section="generator"
              class={["btn btn-ghost justify-start", @active_section == :generator && "btn-active"]}
            >
              <.icon name="hero-sparkles" class="size-5 mr-2" /> Generator
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
  attr(:show_register_form, :boolean, default: false)
  attr(:show_login_form, :boolean, default: false)
  attr(:form, :map, default: nil)

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
        data_cy="register-modal"
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
        </.form>
        <:actions>
          <button
            data-cy="register-cancel"
            type="button"
            phx-click="close_auth_form"
            class="btn"
          >
            Anuluj
          </button>
          <button data-cy="register-submit" type="submit" form="register-form" class="btn btn-primary">
            Zarejestruj się
          </button>
        </:actions>
      </.modal>

      <%!-- Login Modal --%>
      <.modal
        :if={@show_login_form}
        data_cy="login-modal"
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
        </.form>
        <:actions>
          <button data-cy="login-cancel" type="button" phx-click="close_auth_form" class="btn">
            Anuluj
          </button>
          <button data-cy="login-submit" type="submit" form="login-form" class="btn btn-primary">
            Zaloguj
          </button>
        </:actions>
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
  # Dashboard Section
  # ============================================================================

  @doc """
  Renders the dashboard with user stats and quick actions.
  """
  attr(:current_user, :map, required: true)

  attr(:user_stats, :map,
    default: %{strategies_count: 0, simulations_count: 0, best_strategy: nil}
  )

  attr(:recent_simulations, :list, default: [])
  attr(:live_attempts, :map, default: %{})
  attr(:strategy_pools, :map, default: %{})

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
              data-cy="quick-create-strategy"
              phx-click="navigate"
              phx-value-section="strategies"
              class="btn btn-primary btn-lg"
            >
              <.icon name="hero-plus-circle" class="size-6" /> Utwórz nową strategię
            </button>
            <button
              data-cy="quick-run-simulation"
              phx-click="navigate"
              phx-value-section="simulations"
              class="btn btn-primary btn-lg"
            >
              <.icon name="hero-play" class="size-6" /> Uruchom symulację
            </button>
            <button
              data-cy="quick-generate-coupons"
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
            <div class="space-y-4">
              <div class="overflow-x-auto">
                <table class="table table-zebra">
                  <thead>
                    <tr>
                      <th>Strategia</th>
                      <th>Szczegóły strategii</th>
                      <th>Target Draw</th>
                      <th>Poszukiwane liczby</th>
                      <th>Data utworzenia</th>
                      <th>Liczba prób</th>
                      <th>Status</th>
                      <th>Akcje</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for sim <- @recent_simulations do %>
                      <tr>
                        <td class="font-medium">
                          {if Ecto.assoc_loaded?(sim.strategy) && sim.strategy,
                            do: sim.strategy.name,
                            else: "—"}
                        </td>
                        <td>
                          <%= if @strategy_pools && Map.has_key?(@strategy_pools, sim.id) do %>
                            {pools = Map.get(@strategy_pools, sim.id)
                            render_strategy_pools(pools)}
                          <% else %>
                            <span>—</span>
                          <% end %>
                        </td>
                        <td>
                          {if Ecto.assoc_loaded?(sim.target_draw) && sim.target_draw,
                            do: Calendar.strftime(sim.target_draw.draw_date, "%Y-%m-%d"),
                            else: "—"}
                        </td>
                        <td>
                          <%= if Ecto.assoc_loaded?(sim.target_draw) && sim.target_draw do %>
                            <div class="space-y-1">
                              <div class="flex items-center gap-2 text-xs">
                                <.number_ball
                                  numbers={sim.target_draw.numbers.main_numbers}
                                  type="main"
                                  size="xs"
                                />
                              </div>
                              <div class="flex items-center gap-2 text-xs">
                                <.number_ball
                                  numbers={sim.target_draw.numbers.euro_numbers}
                                  type="euro"
                                  size="xs"
                                />
                              </div>
                            </div>
                          <% else %>
                            <span>—</span>
                          <% end %>
                        </td>
                        <td>{Calendar.strftime(sim.inserted_at, "%Y-%m-%d %H:%M")}</td>
                        <td>
                          {cond do
                            sim.status == "running" && @live_attempts ->
                              sim_id_string = to_string(sim.id)

                              if Map.has_key?(@live_attempts, sim_id_string) do
                                attempts = Map.get(@live_attempts, sim_id_string)
                                "<span class=\"font-mono\">#{format_number(attempts)}</span>"
                              else
                                if sim.attempts_count && sim.attempts_count > 0 do
                                  "<span>#{format_number(sim.attempts_count)}</span>"
                                else
                                  "<span>—</span>"
                                end
                              end

                            sim.attempts_count && sim.attempts_count > 0 ->
                              "<span>#{format_number(sim.attempts_count)}</span>"

                            true ->
                              "<span>—</span>"
                          end
                          |> Phoenix.HTML.raw()}
                        </td>
                        <td>
                          <div class="flex flex-col gap-1">
                            <.status_indicator status={sim.status} />
                            <%= if sim.status == "error" && sim.result && sim.result.error_message do %>
                              <div
                                class="text-xs text-error mt-1 max-w-xs truncate"
                                title={sim.result.error_message}
                              >
                                {sim.result.error_message}
                              </div>
                            <% end %>
                          </div>
                        </td>
                        <td>
                          <div class="flex flex-col gap-1">
                            <%= if sim.status == "max_attempts_reached" do %>
                              <button
                                phx-click="show_update_max_attempts"
                                phx-value-id={sim.id}
                                class="btn btn-sm btn-warning"
                                title="Zmień limit prób"
                              >
                                <.icon name="hero-cog-6-tooth" class="size-4" /> {"Zmień limit prób"}
                              </button>
                            <% end %>
                            <%= if sim.status == "timeout" do %>
                              <button
                                phx-click="show_update_timeout"
                                phx-value-id={sim.id}
                                class="btn btn-sm btn-warning"
                                title="Zmień timeout"
                              >
                                <.icon name="hero-cog-6-tooth" class="size-4" /> {"Zmień timeout"}
                              </button>
                            <% end %>
                            <button
                              phx-click="toggle_favorite"
                              phx-value-id={sim.id}
                              class={[
                                "btn btn-sm",
                                if(sim.is_favorite, do: "btn-warning", else: "btn-ghost")
                              ]}
                              title={
                                if sim.is_favorite,
                                  do: "Odznacz jako ulubioną",
                                  else: "Oznacz jako ulubioną"
                              }
                            >
                              <.icon
                                name={if sim.is_favorite, do: "hero-star-solid", else: "hero-star"}
                                class="size-4"
                              />
                              {if sim.is_favorite, do: "Oznaczona", else: "Oznacz"}
                            </button>
                            <%= if sim.status in ["error", "timeout", "max_attempts_reached", "success", "cancelled"] do %>
                              <button
                                phx-click="retry_simulation"
                                phx-value-id={sim.id}
                                class="btn btn-sm btn-primary"
                                title="Ponów symulację"
                              >
                                <.icon name="hero-arrow-path" class="size-4" /> {"Ponów"}
                              </button>
                            <% end %>
                            <button
                              phx-click="delete_simulation"
                              phx-value-id={sim.id}
                              class="btn btn-sm btn-error"
                              title="Usuń symulację"
                              data-confirm="Czy na pewno chcesz usunąć tę symulację?"
                            >
                              <.icon name="hero-trash" class="size-4" /> {"Usuń"}
                            </button>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
              <div class="flex justify-end">
                <button
                  phx-click="navigate"
                  phx-value-section="simulations"
                  class="btn btn-sm btn-ghost"
                >
                  Zobacz wszystkie symulacje <.icon name="hero-arrow-right" class="size-4" />
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Format number with thousand separators
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

  attr(:icon, :string, required: true)
  attr(:title, :string, required: true)
  attr(:value, :string, required: true)

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

  defp render_strategy_pools(pools) do
    main_pools = pools.main_numbers
    euro_pools = pools.euro_numbers

    assigns = %{main_pools: main_pools, euro_pools: euro_pools}

    ~H"""
    <div class="text-xs space-y-1 max-w-xs">
      <div>
        <span class="font-semibold text-error">Hot:</span>
        <span class="ml-1">{Enum.join(Enum.sort(@main_pools.hot), ", ")}</span>
      </div>
      <div>
        <span class="font-semibold text-info">Cold:</span>
        <span class="ml-1">{Enum.join(Enum.sort(@main_pools.cold), ", ")}</span>
      </div>
      <div>
        <span class="font-semibold text-base-content/60">Random:</span>
        <span class="ml-1">{length(@main_pools.random)} liczb</span>
      </div>
      <div class="pt-1 border-t border-base-300">
        <span class="font-semibold">Euro Hot:</span>
        <span class="ml-1">{Enum.join(Enum.sort(@euro_pools.hot), ", ")}</span>
      </div>
      <div>
        <span class="font-semibold text-base-content/60">Euro Random:</span>
        <span class="ml-1">{length(@euro_pools.random)} liczb</span>
      </div>
    </div>
    """
  end
end
