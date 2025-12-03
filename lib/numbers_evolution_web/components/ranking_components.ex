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

  def ranking_section(assigns) do
    strategies_with_scores =
      assigns.strategies
      |> Enum.reject(&is_nil(&1.performance_score))
      |> Enum.sort_by(& &1.performance_score, :desc)

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
              <div class="stat-title">Performance Score</div>
              <div class="stat-value text-primary">
                {Float.round(@strategy.performance_score, 2)}
              </div>
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
