defmodule NumbersEvolutionWeb.RankingComponents do
  @moduledoc """
  Components for the ranking section.
  Shows strategies sorted by performance score.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents

  # ============================================================================
  # Main Ranking Section
  # ============================================================================

  @doc """
  Renders the ranking section with strategies sorted by performance.
  """
  attr :strategies, :list, required: true
  attr :strategy_stats, :list, default: []

  def ranking_section(assigns) do
    # performance_score is the median attempts to jackpot - lower is better
    strategies_with_scores =
      assigns.strategies
      |> Enum.reject(&is_nil(&1.performance_score))
      |> Enum.sort_by(& &1.performance_score, :asc)

    strategies_without_scores =
      assigns.strategies
      |> Enum.filter(&is_nil(&1.performance_score))

    assigns =
      assigns
      |> assign(:ranked_strategies, strategies_with_scores)
      |> assign(:unranked_strategies, strategies_without_scores)

    ~H"""
    <div class="space-y-8">
      <h1 class="text-4xl font-bold">Ranking Strategii</h1>

      <.analytics_table :if={@strategy_stats != []} strategy_stats={@strategy_stats} />

      <%= if @ranked_strategies == [] do %>
        <.empty_state icon="hero-trophy">
          <:title>Brak danych rankingowych</:title>
          <:description>Uruchom symulacje aby zobaczyć ranking strategii</:description>
          <:action>
            <button
              phx-click="navigate"
              phx-value-section="simulations"
              class="btn btn-primary btn-lg"
            >
              Uruchom symulację
            </button>
          </:action>
        </.empty_state>
      <% else %>
        <div class="space-y-4">
          <%= for {strategy, index} <- Enum.with_index(@ranked_strategies, 1) do %>
            <.ranking_card strategy={strategy} position={index} />
          <% end %>

          <%= if @unranked_strategies != [] do %>
            <div class="divider">Strategie bez symulacji</div>
            <%= for strategy <- @unranked_strategies do %>
              <.unranked_strategy_card strategy={strategy} />
            <% end %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Analytics Table
  # ============================================================================

  attr :strategy_stats, :list, required: true

  defp analytics_table(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow">
      <div class="card-body">
        <h2 class="card-title text-lg">
          Analiza skuteczności
          <span class="text-xs font-normal text-base-content/60">
            (per strategia i tryb generowania)
          </span>
        </h2>
        <div class="overflow-x-auto">
          <table class="table table-zebra table-sm w-full">
            <thead>
              <tr>
                <th>Strategia</th>
                <th>Tryb</th>
                <th class="text-right">Symulacje</th>
                <th class="text-right">Sukcesy</th>
                <th class="text-right">Mediana prób</th>
                <th class="text-right">Przestrzeń kombinacji</th>
                <th
                  class="text-right"
                  title="Mediana prób / rozmiar przestrzeni - im mniejsza przestrzeń, tym szybciej strategia trafia"
                >
                  Mediana / przestrzeń
                </th>
                <th>Trafienia / 100k prób</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={stats <- @strategy_stats}>
                <td class="font-medium max-w-40 truncate" title={stats.strategy.name}>
                  {stats.strategy.name}
                </td>
                <td><.mode_badge mode={stats.mode} /></td>
                <td class="text-right">{stats.simulations_count}</td>
                <td class="text-right">
                  {stats.success_count} ({round(stats.success_rate * 100)}%)
                </td>
                <td class="text-right font-mono">{format_number(stats.median_attempts)}</td>
                <td class="text-right font-mono">{format_number(stats.search_space)}</td>
                <td class="text-right font-mono">
                  {format_ratio(stats.expected_vs_actual)}
                </td>
                <td>
                  <.tier_bars tiers_per_100k={stats.tiers_per_100k} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="text-xs text-base-content/60 mt-2">
          Przestrzeń kombinacji pokazuje, dlaczego strategie różnią się skutecznością:
          pełna pula Eurojackpot to ~139,8 mln kombinacji, auto-blacklist 25/6 zmniejsza
          ją do ~796 tys., a 35/8 do ~18 tys. Zwykłe reguły (hot/cold, proporcje)
          praktycznie nie zmniejszają przestrzeni.
        </p>
      </div>
    </div>
    """
  end

  attr :mode, :atom, required: true

  defp mode_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      @mode == :auto_blacklist && "badge-secondary",
      @mode == :vip1 && "badge-warning",
      @mode == :half_random && "badge-info",
      @mode == :standard && "badge-ghost"
    ]}>
      {mode_label(@mode)}
    </span>
    """
  end

  defp mode_label(:auto_blacklist), do: "Auto-BL"
  defp mode_label(:vip1), do: "VIP1"
  defp mode_label(:half_random), do: "Half-random"
  defp mode_label(:standard), do: "Standard"

  attr :tiers_per_100k, :map, required: true

  defp tier_bars(assigns) do
    # Show the highest tiers hit (lower tier number = bigger prize)
    top_tiers =
      assigns.tiers_per_100k
      |> Enum.filter(fn {_tier, per_100k} -> per_100k > 0 end)
      |> Enum.sort_by(fn {tier, _} -> tier end)
      |> Enum.take(4)

    assigns = assign(assigns, :top_tiers, top_tiers)

    ~H"""
    <div class="flex flex-wrap gap-1">
      <span
        :for={{tier, per_100k} <- @top_tiers}
        class="badge badge-outline badge-xs font-mono"
        title={"Tier #{tier}: #{format_number(per_100k)} trafień na 100k prób"}
      >
        T{tier}: {format_number(per_100k)}
      </span>
      <span :if={@top_tiers == []} class="text-base-content/40 text-xs">—</span>
    </div>
    """
  end

  defp format_number(nil), do: "—"

  defp format_number(number) when is_float(number) do
    if number < 10 do
      :erlang.float_to_binary(number, decimals: 2)
    else
      format_number(round(number))
    end
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+$)/, "\\1 ")
  end

  defp format_ratio(nil), do: "—"
  defp format_ratio(ratio), do: "#{:erlang.float_to_binary(ratio * 1.0, decimals: 2)}×"

  # ============================================================================
  # Private Components
  # ============================================================================

  attr :strategy, :map, required: true
  attr :position, :integer, required: true

  defp ranking_card(assigns) do
    ~H"""
    <.card class={
      cond do
        @position == 1 -> "ring-2 ring-warning"
        @position == 2 -> "ring-2 ring-base-300"
        @position == 3 -> "ring-2 ring-amber-700"
        true -> ""
      end
    }>
      <div class="flex items-center gap-4">
        <div class={[
          "text-3xl font-bold w-12 text-center",
          @position == 1 && "text-warning",
          @position == 2 && "text-base-300",
          @position == 3 && "text-amber-700"
        ]}>
          #{@position}
        </div>

        <div class="flex-1">
          <div class="flex items-center gap-2 mb-2">
            <%= if @position <= 3 do %>
              <.icon
                name="hero-trophy"
                class={"size-6 #{cond do
                  @position == 1 -> "text-warning"
                  @position == 2 -> "text-base-300"
                  @position == 3 -> "text-amber-700"
                  true -> ""
                end}"}
              />
            <% end %>
            <h3 class="font-bold text-xl">{@strategy.name}</h3>
            <.badge
              variant={if @strategy.type == :ai_generated, do: "success", else: "info"}
              size="sm"
            >
              {if @strategy.type == :ai_generated, do: "AI", else: "Manual"}
            </.badge>
          </div>

          <div class="stats stats-horizontal shadow">
            <div class="stat">
              <div class="stat-title">Mediana prób do jackpotu</div>
              <div class="stat-value text-primary">
                {format_number(@strategy.performance_score)}
              </div>
              <div class="stat-desc">mniej = lepiej</div>
            </div>
          </div>
        </div>
      </div>
    </.card>
    """
  end

  attr :strategy, :map, required: true

  defp unranked_strategy_card(assigns) do
    ~H"""
    <.card class="opacity-60">
      <div class="flex items-center gap-4">
        <div class="text-3xl font-bold w-12 text-center text-base-content/30">—</div>
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <h3 class="font-bold text-lg">{@strategy.name}</h3>
            <.badge variant="neutral" size="sm">Brak danych</.badge>
          </div>
          <button
            phx-click="navigate"
            phx-value-section="simulations"
            class="btn btn-sm btn-primary mt-2"
          >
            Uruchom symulację
          </button>
        </div>
      </div>
    </.card>
    """
  end
end
