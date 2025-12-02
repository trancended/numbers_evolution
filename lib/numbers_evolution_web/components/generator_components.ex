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
        <.generator_form strategies={@top_strategies} />

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
    <div class="card bg-base-200">
      <div class="card-body">
        <h2 class="card-title">Top 3 Strategie</h2>
        <div class="grid md:grid-cols-3 gap-4 mt-6">
          <%= for {strategy, index} <- Enum.with_index(@strategies, 1) do %>
            <div class="card bg-base-100">
              <div class="card-body">
                <div class="flex items-center gap-2">
                  <span class="text-2xl font-bold">#{index}</span>
                  <h3 class="font-semibold">{strategy.name}</h3>
                </div>
                <p class="text-sm">
                  Score: {if strategy.performance_score,
                    do: Float.round(strategy.performance_score, 2),
                    else: "—"}
                </p>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :strategies, :list, required: true

  defp generator_form(assigns) do
    ~H"""
    <form phx-submit="generate_coupons" class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title">Generuj propozycje</h2>
        <div class="flex gap-6 mt-6">
          <div class="form-control flex-1">
            <label class="label mb-3">
              <span class="label-text">Wybierz strategię</span>
            </label>
            <select name="strategy_id" class="select select-bordered" required>
              <option value="" disabled selected>Wybierz strategię...</option>
              <%= for strategy <- @strategies do %>
                <option value={strategy.id}>{strategy.name}</option>
              <% end %>
            </select>
          </div>
          <div class="form-control flex-1">
            <label class="label mb-3">
              <span class="label-text">Liczba kuponów (1-10)</span>
            </label>
            <div class="w-full px-2">
              <input
                type="range"
                name="coupons_count"
                id="coupons_count_slider"
                list="coupons_tickmarks"
                min="1"
                max="10"
                value="5"
                step="1"
                class="range range-primary range-xs"
                style="width: 100%;"
                oninput="document.getElementById('coupons_count_display').textContent = this.value"
              />
              <datalist id="coupons_tickmarks">
                <%= for i <- 1..10 do %>
                  <option value={i}></option>
                <% end %>
              </datalist>
              <div class="flex w-full justify-between text-xs mt-1">
                <%= for _ <- 1..10 do %>
                  <span>|</span>
                <% end %>
              </div>
            </div>
            <div class="flex justify-between text-xs mt-2 px-2">
              <span>1</span>
              <span id="coupons_count_display" class="font-bold text-lg text-primary">5</span>
              <span>10</span>
            </div>
          </div>
        </div>
        <button type="submit" class="btn btn-primary mt-4">
          <.icon name="hero-sparkles" class="size-5" /> Generuj propozycje
        </button>
      </div>
    </form>
    """
  end

  attr :coupons, :list, required: true

  defp generated_coupons_display(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h2 class="text-2xl font-bold">Wygenerowane kupony</h2>
        <button type="button" phx-click="regenerate_coupons" class="btn btn-secondary">
          <.icon name="hero-arrow-path" class="size-5" /> Wylosuj inne
        </button>
      </div>

      <div class="grid md:grid-cols-2 gap-4 mt-6">
        <%= for {coupon, index} <- Enum.with_index(@coupons, 1) do %>
          <.card>
            <:title>Kupon {index}</:title>
            <div class="space-y-4">
              <div>
                <p class="text-sm font-semibold mb-2">Główne liczby:</p>
                <.number_ball numbers={coupon.main_numbers} type="main" size="md" />
              </div>
              <div>
                <p class="text-sm font-semibold mb-2">Euro liczby:</p>
                <.number_ball numbers={coupon.euro_numbers} type="euro" size="md" />
              </div>
            </div>
          </.card>
        <% end %>
      </div>
    </div>
    """
  end
end
