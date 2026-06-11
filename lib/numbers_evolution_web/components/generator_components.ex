defmodule NumbersEvolutionWeb.GeneratorComponents do
  @moduledoc """
  Components for the coupon generator section.
  Generates coupon suggestions based on top-performing strategies.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents

  # ============================================================================
  # Main Generator Section
  # ============================================================================

  @doc """
  Renders the coupon generator section.
  """
  attr :top_strategies, :list, required: true
  attr :generated_coupons, :list, default: []
  attr :selected_game, :string, default: nil

  def generator_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <h1 class="text-4xl font-bold">Generator Propozycji</h1>

      <%= if @top_strategies == [] do %>
        <.empty_state icon="hero-sparkles">
          <:title>Brak top strategii</:title>
          <:description>
            Najpierw uruchom symulacje aby znaleźć najlepsze strategie
          </:description>
          <:action>
            <button phx-click="navigate" phx-value-section="strategies" class="btn btn-primary">
              Wygeneruj strategię przez AI
            </button>
            <button phx-click="navigate" phx-value-section="simulations" class="btn btn-secondary">
              Uruchom symulację
            </button>
          </:action>
        </.empty_state>
      <% else %>
        <.top_strategies_display strategies={@top_strategies} />
        <.generator_form strategies={@top_strategies} selected_game={@selected_game} />

        <%= if @generated_coupons != [] do %>
          <.generated_coupons_display coupons={@generated_coupons} />
        <% end %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Private Components
  # ============================================================================

  attr :strategies, :list, required: true

  defp top_strategies_display(assigns) do
    ~H"""
    <div class="card bg-base-200/50 border border-base-300">
      <div class="card-body">
        <h2 class="card-title text-xl flex items-center gap-2">
          <.icon name="hero-trophy" class="size-6 text-warning" />
          <span>Top 3 Strategie</span>
        </h2>
        <div class="grid md:grid-cols-3 gap-4 mt-6">
          <%= for {strategy, index} <- Enum.with_index(@strategies, 1) do %>
            <div class="card bg-base-100 border-2 border-base-300 hover:border-primary transition-colors">
              <div class="card-body">
                <div class="flex items-start gap-3">
                  <div class={[
                    "flex items-center justify-center w-10 h-10 rounded-full font-bold text-lg",
                    index == 1 && "bg-warning/20 text-warning",
                    index == 2 && "bg-base-300 text-base-content",
                    index == 3 && "bg-base-300/50 text-base-content/70"
                  ]}>
                    #{index}
                  </div>
                  <div class="flex-1 min-w-0">
                    <h3 class="font-semibold text-base truncate" title={strategy.name}>
                      {strategy.name}
                    </h3>
                    <div class="flex items-center gap-2 mt-2">
                      <span class="text-xs text-base-content/60">Score:</span>
                      <span class="text-sm font-bold text-primary">
                        {if strategy.performance_score,
                          do: Float.round(strategy.performance_score, 2),
                          else: "—"}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :strategies, :list, required: true
  attr :selected_game, :string, default: nil

  defp generator_form(assigns) do
    assigns =
      assign(
        assigns,
        :selected_game,
        assigns.selected_game || NumbersEvolution.Games.default_id()
      )

    ~H"""
    <form phx-submit="generate_coupons" class="card bg-base-100 shadow-xl border-2 border-base-300">
      <div class="card-body">
        <h2 class="card-title text-xl flex items-center gap-2 mb-4">
          <.icon name="hero-sparkles" class="size-6 text-primary" />
          <span>Generuj propozycje</span>
        </h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-2">
          <div class="form-control">
            <label class="label mb-2">
              <span class="label-text font-semibold">Gra</span>
            </label>
            <select name="game_type" class="select select-bordered w-full">
              <%= for {label, id} <- NumbersEvolution.Games.select_options() do %>
                <option value={id} selected={id == @selected_game}>{label}</option>
              <% end %>
            </select>
          </div>
          <div class="form-control">
            <label class="label mb-2">
              <span class="label-text font-semibold">Wybierz strategię</span>
            </label>
            <select name="strategy_id" class="select select-bordered w-full" required>
              <option value="" disabled selected>Wybierz strategię...</option>
              <%= for strategy <- @strategies do %>
                <option value={strategy.id}>{strategy.name}</option>
              <% end %>
            </select>
          </div>
          <div class="form-control">
            <label class="label mb-2">
              <span class="label-text font-semibold">Liczba kuponów</span>
            </label>
            <div class="bg-base-200/50 p-4 rounded-lg border border-base-300">
              <input
                type="range"
                name="coupons_count"
                id="coupons_count_slider"
                list="coupons_tickmarks"
                min="1"
                max="10"
                value="5"
                step="1"
                class="range range-primary w-full"
                oninput="document.getElementById('coupons_count_display').textContent = this.value"
              />
              <datalist id="coupons_tickmarks">
                <%= for i <- 1..10 do %>
                  <option value={i}></option>
                <% end %>
              </datalist>
              <div class="flex w-full justify-between text-xs mt-2 px-1">
                <%= for i <- 1..10 do %>
                  <span class="text-base-content/40">{i}</span>
                <% end %>
              </div>
              <div class="text-center mt-3">
                <span
                  id="coupons_count_display"
                  class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/20 font-bold text-3xl text-primary"
                >
                  5
                </span>
              </div>
            </div>
          </div>
        </div>
        <button type="submit" class="btn btn-primary w-full mt-6 text-base py-3 h-auto">
          <.icon name="hero-sparkles" class="size-5" /> Generuj propozycje
        </button>
      </div>
    </form>
    """
  end

  attr :coupons, :list, required: true

  defp generated_coupons_display(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <h2 class="text-2xl font-bold flex items-center gap-2">
          <.icon name="hero-ticket" class="size-7 text-success" />
          <span>Wygenerowane kupony</span>
        </h2>
        <button
          type="button"
          phx-click="regenerate_coupons"
          class="btn btn-secondary gap-2 w-full sm:w-auto"
        >
          <.icon name="hero-arrow-path" class="size-5" /> Wylosuj inne
        </button>
      </div>

      <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for {coupon, index} <- Enum.with_index(@coupons, 1) do %>
          <div class="card bg-base-100 border-2 border-base-300 hover:border-primary hover:shadow-lg transition-all">
            <div class="card-body">
              <div class="flex items-center justify-between mb-4">
                <h3 class="card-title text-lg">Kupon {index}</h3>
                <div class="badge badge-primary badge-lg">#{index}</div>
              </div>
              <div class="space-y-5">
                <div>
                  <div class="flex items-center gap-2 mb-3">
                    <div class="w-3 h-3 rounded-full bg-blue-500"></div>
                    <p class="text-sm font-semibold">Główne liczby:</p>
                  </div>
                  <div class="flex justify-center">
                    <.number_ball numbers={coupon.main_numbers} type="main" size="md" />
                  </div>
                </div>
                <%= if coupon.euro_numbers != [] do %>
                  <div class="divider my-2"></div>
                  <div>
                    <div class="flex items-center gap-2 mb-3">
                      <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
                      <p class="text-sm font-semibold">Euro liczby:</p>
                    </div>
                    <div class="flex justify-center">
                      <.number_ball numbers={coupon.euro_numbers} type="euro" size="md" />
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
