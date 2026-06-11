defmodule NumbersEvolutionWeb.DashboardComponents do
  @moduledoc """
  Components for the dashboard section.
  Shows user statistics, quick actions, and recent simulations.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents
  import NumbersEvolutionWeb.SharedComponents

  # ============================================================================
  # Main Dashboard Section
  # ============================================================================

  @doc """
  Renders the dashboard with user stats and quick actions.
  """
  attr :current_user, :map, required: true

  attr :user_stats, :map,
    default: %{strategies_count: 0, simulations_count: 0, best_strategy: nil}

  attr :recent_simulations, :list, default: []
  attr :live_attempts, :map, default: %{}
  attr :strategy_pools, :map, default: %{}

  def dashboard_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <h1 class="text-4xl font-bold">Dashboard</h1>
      <p class="text-lg">Witaj, {@current_user.email}</p>

      <%!-- Stats Cards --%>
      <.stats_grid user_stats={@user_stats} />

      <%!-- Quick Actions --%>
      <.quick_actions />

      <%!-- Recent Simulations --%>
      <.recent_simulations_section
        recent_simulations={@recent_simulations}
        live_attempts={@live_attempts}
        strategy_pools={@strategy_pools}
      />
    </div>
    """
  end

  # ============================================================================
  # Private Components
  # ============================================================================

  attr :user_stats, :map, required: true

  defp stats_grid(assigns) do
    ~H"""
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

  defp quick_actions(assigns) do
    ~H"""
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
    """
  end

  attr :recent_simulations, :list, required: true
  attr :live_attempts, :map, required: true
  attr :strategy_pools, :map, required: true

  defp recent_simulations_section(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title">Ostatnie symulacje</h2>
        <%= if @recent_simulations == [] do %>
          <.empty_state icon="hero-chart-bar">
            <:title>Nie masz jeszcze żadnych symulacji</:title>
            <:action>
              <button
                phx-click="navigate"
                phx-value-section="simulations"
                class="btn btn-primary mt-4"
              >
                Uruchom pierwszą symulację
              </button>
            </:action>
          </.empty_state>
        <% else %>
          <div class="space-y-4">
            <.recent_simulations_table
              simulations={@recent_simulations}
              live_attempts={@live_attempts}
              strategy_pools={@strategy_pools}
            />
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
    """
  end

  attr :simulations, :list, required: true
  attr :live_attempts, :map, required: true
  attr :strategy_pools, :map, required: true

  defp recent_simulations_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-zebra">
        <thead>
          <tr>
            <th>Strategia</th>
            <th>Target Draw</th>
            <th>Poszukiwane liczby</th>
            <th>Data utworzenia</th>
            <th>Liczba prób</th>
            <th>Status</th>
            <th>Akcje</th>
          </tr>
        </thead>
        <tbody>
          <%= for sim <- @simulations do %>
            <.simulation_row
              simulation={sim}
              live_attempts={@live_attempts}
              strategy_pools={@strategy_pools}
            />
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :simulation, :map, required: true
  attr :live_attempts, :map, required: true
  attr :strategy_pools, :map, required: true

  defp simulation_row(assigns) do
    ~H"""
    <tr>
      <td class="font-medium">
        {if Ecto.assoc_loaded?(@simulation.strategy) && @simulation.strategy,
          do: @simulation.strategy.name,
          else: "—"}
      </td>
      <td>
        {if Ecto.assoc_loaded?(@simulation.target_draw) && @simulation.target_draw,
          do: Calendar.strftime(@simulation.target_draw.draw_date, "%Y-%m-%d"),
          else: "—"}
      </td>
      <td>
        <%= if Ecto.assoc_loaded?(@simulation.target_draw) && @simulation.target_draw do %>
          <div class="space-y-1">
            <div class="flex items-center gap-2 text-xs">
              <.number_ball
                numbers={@simulation.target_draw.numbers.main_numbers}
                type="main"
                size="xs"
              />
            </div>
            <div
              :if={@simulation.target_draw.numbers.euro_numbers != []}
              class="flex items-center gap-2 text-xs"
            >
              <.number_ball
                numbers={@simulation.target_draw.numbers.euro_numbers}
                type="euro"
                size="xs"
              />
            </div>
          </div>
        <% else %>
          <span>—</span>
        <% end %>
      </td>
      <td>{Calendar.strftime(@simulation.inserted_at, "%Y-%m-%d %H:%M")}</td>
      <td>
        {cond do
          @simulation.status == "running" && @live_attempts ->
            sim_id_string = to_string(@simulation.id)

            if Map.has_key?(@live_attempts, sim_id_string) do
              attempts = Map.get(@live_attempts, sim_id_string)
              "<span class=\"font-mono\">#{format_number(attempts)}</span>"
            else
              if @simulation.attempts_count && @simulation.attempts_count > 0 do
                "<span>#{format_number(@simulation.attempts_count)}</span>"
              else
                "<span>—</span>"
              end
            end

          @simulation.attempts_count && @simulation.attempts_count > 0 ->
            "<span>#{format_number(@simulation.attempts_count)}</span>"

          true ->
            "<span>—</span>"
        end
        |> Phoenix.HTML.raw()}
      </td>
      <td>
        <div class="flex flex-col gap-1">
          <.status_indicator status={@simulation.status} />
          <%= if @simulation.status == "error" && @simulation.result && @simulation.result.error_message do %>
            <div
              class="text-xs text-error mt-1 max-w-xs truncate"
              title={@simulation.result.error_message}
            >
              {@simulation.result.error_message}
            </div>
          <% end %>
        </div>
      </td>
      <td>
        <.simulation_action_buttons simulation={@simulation} />
      </td>
    </tr>
    """
  end

  attr :simulation, :map, required: true

  defp simulation_action_buttons(assigns) do
    ~H"""
    <div class="flex flex-col gap-1">
      <%= if @simulation.status == "max_attempts_reached" do %>
        <button
          phx-click="show_update_max_attempts"
          phx-value-id={@simulation.id}
          class="btn btn-sm btn-warning"
          title="Zmień limit prób"
        >
          <.icon name="hero-cog-6-tooth" class="size-4" /> {"Zmień limit prób"}
        </button>
      <% end %>
      <%= if @simulation.status == "timeout" do %>
        <button
          phx-click="show_update_timeout"
          phx-value-id={@simulation.id}
          class="btn btn-sm btn-warning"
          title="Zmień timeout"
        >
          <.icon name="hero-cog-6-tooth" class="size-4" /> {"Zmień timeout"}
        </button>
      <% end %>
      <button
        phx-click="toggle_favorite"
        phx-value-id={@simulation.id}
        class={["btn btn-sm", if(@simulation.is_favorite, do: "btn-warning", else: "btn-ghost")]}
        title={if @simulation.is_favorite, do: "Odznacz jako ulubioną", else: "Oznacz jako ulubioną"}
      >
        <.icon
          name={if @simulation.is_favorite, do: "hero-star-solid", else: "hero-star"}
          class="size-4"
        />
        {if @simulation.is_favorite, do: "Oznaczona", else: "Oznacz"}
      </button>
      <%= if @simulation.status in ["error", "timeout", "max_attempts_reached", "success", "cancelled"] do %>
        <button
          phx-click="retry_simulation"
          phx-value-id={@simulation.id}
          class="btn btn-sm btn-primary"
          title="Ponów symulację"
        >
          <.icon name="hero-arrow-path" class="size-4" /> {"Ponów"}
        </button>
      <% end %>
      <button
        phx-click="delete_simulation"
        phx-value-id={@simulation.id}
        class="btn btn-sm btn-error"
        title="Usuń symulację"
        data-confirm="Czy na pewno chcesz usunąć tę symulację?"
      >
        <.icon name="hero-trash" class="size-4" /> {"Usuń"}
      </button>
    </div>
    """
  end
end
