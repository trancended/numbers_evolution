defmodule NumbersEvolutionWeb.SimulationComponents do
  @moduledoc """
  Components for the simulations section.
  Handles simulation forms, tables, details modals, and pool visualization.
  This is the largest and most complex component module due to simulation complexity.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents
  import NumbersEvolutionWeb.SharedComponents

  # ============================================================================
  # Main Simulations Section
  # ============================================================================

  @doc """
  Renders the simulations section with form and history.
  """
  attr :strategies, :list, required: true
  attr :simulations, :list, required: true
  attr :draws, :list, required: true
  attr :live_attempts, :map, default: %{}
  attr :live_prize_tiers, :map, default: %{}
  attr :strategy_pools, :map, default: %{}
  attr :selected_strategy, :any, default: nil
  attr :target_validation_error, :string, default: nil

  def simulations_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <h1 class="text-4xl font-bold">Symulacje</h1>

      <%!-- Start Simulation Form --%>
      <.card class="bg-base-200" title_class="justify-center">
        <:title>Uruchom nową symulację</:title>

        <%= if @strategies == [] do %>
          <.alert kind="warning">
            Najpierw utwórz strategię, aby móc uruchamiać symulacje.
            <button
              phx-click="navigate"
              phx-value-section="strategies"
              class="btn btn-sm btn-primary mt-2"
            >
              Przejdź do strategii
            </button>
          </.alert>
        <% else %>
          <.simulation_form
            strategies={@strategies}
            draws={@draws}
            selected_strategy={@selected_strategy}
            strategy_pools={@strategy_pools}
            target_validation_error={@target_validation_error}
          />
        <% end %>
      </.card>

      <%!-- Simulations History --%>
      <.card>
        <:title>Historia symulacji</:title>

        <%= if @simulations == [] do %>
          <.empty_state icon="hero-chart-bar">
            <:title>Brak symulacji</:title>
            <:description>Uruchom swoją pierwszą symulację, aby przetestować strategię</:description>
          </.empty_state>
        <% else %>
          <.simulations_table
            simulations={@simulations}
            live_attempts={@live_attempts}
            live_prize_tiers={@live_prize_tiers}
            strategy_pools={@strategy_pools}
          />
        <% end %>
      </.card>
    </div>
    """
  end

  # ============================================================================
  # Simulation Form (imported from sections_components.ex lines 490-694)
  # ============================================================================

  attr :strategies, :list, required: true
  attr :draws, :list, required: true
  attr :selected_strategy, :any, default: nil
  attr :strategy_pools, :map, default: %{}
  attr :target_validation_error, :string, default: nil

  defp simulation_form(assigns) do
    ~H"""
    <form phx-submit="start_simulation" class="space-y-4">
      <%!-- Sekcja wyboru strategii i losowania --%>
      <div class="bg-base-100/50 p-4 rounded-lg border border-base-300/50">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="form-control">
            <label class="label mb-1.5">
              <span class="label-text font-semibold flex items-center gap-2">
                <.icon name="hero-rocket-launch" class="size-4 text-primary" /> Strategia
              </span>
            </label>
            <select
              data-cy="strategy-select"
              name="strategy_id"
              class="select select-bordered w-full"
              required
              phx-change="strategy_changed"
            >
              <option value="" disabled selected>Wybierz strategię...</option>
              <%= for strategy <- @strategies do %>
                <option value={strategy.id}>{strategy.name}</option>
              <% end %>
            </select>
          </div>

          <div class="form-control">
            <label class="label mb-1.5">
              <span class="label-text font-semibold flex items-center gap-2">
                <.icon name="hero-calendar" class="size-4 text-primary" /> Losowanie docelowe
              </span>
              <%= if @selected_strategy && vip_strategy?(@selected_strategy) do %>
                <span class="label-text-alt text-warning text-xs font-medium">
                  🎯 Filtrowane dla VIP
                </span>
              <% end %>
            </label>
            <select
              data-cy="target-draw-select"
              name="target_draw_id"
              class="select select-bordered w-full"
              required
              phx-change="target_draw_changed"
            >
              <option value="" disabled selected>Wybierz losowanie...</option>
              <%= for draw <- @draws do %>
                <option value={draw.id}>
                  {Calendar.strftime(draw.draw_date, "%Y-%m-%d")} - #{Enum.join(
                    draw.numbers.main_numbers,
                    ", "
                  )} | #{Enum.join(draw.numbers.euro_numbers, ", ")}
                </option>
              <% end %>
            </select>
            <%= if @selected_strategy && vip_strategy?(@selected_strategy) && @draws == [] do %>
              <label class="label">
                <span class="label-text-alt text-error text-xs">
                  ⚠️ Brak losowań spełniających ograniczenia VIP
                </span>
              </label>
            <% end %>
          </div>
        </div>
      </div>

      <%= if @selected_strategy do %>
        <.strategy_pools_display strategy={@selected_strategy} strategy_pools={@strategy_pools} />
      <% end %>

      <%= if @target_validation_error do %>
        <.alert kind="warning">
          <div>
            <p class="font-semibold">Komplet liczb nie pasuje do symulacji</p>
            <p class="text-sm mt-1">{@target_validation_error}</p>
          </div>
        </.alert>
      <% end %>

      <.simulation_options_form />

      <div class="pt-2">
        <button
          data-cy="start-simulation-btn"
          type="submit"
          class="btn btn-primary w-full h-12 text-base font-semibold shadow-lg hover:shadow-xl transition-all duration-200"
        >
          <.icon name="hero-play" class="size-5" /> Uruchom symulację
        </button>
      </div>
    </form>
    """
  end

  attr :strategy, :map, required: true
  attr :strategy_pools, :map, required: true

  defp strategy_pools_display(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-primary/5 to-primary/10 border border-primary/20 p-4 rounded-lg">
      <div class="flex items-center gap-2 mb-3">
        <.icon name="hero-squares-2x2" class="size-4 text-primary" />
        <h4 class="font-semibold text-sm">
          Komplet liczb strategii "<span class="text-primary">{@strategy.name}</span>"
        </h4>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="bg-base-100/70 p-3 rounded-lg space-y-2.5">
          <div class="font-semibold text-error text-sm flex items-center gap-2">
            <div class="w-2.5 h-2.5 rounded-full bg-error"></div>
            <span>Główne liczby (1-50)</span>
          </div>
          <div class="space-y-2 pl-4 text-xs">
            <div class="flex flex-col gap-0.5">
              <span class="font-semibold text-error/80">Hot:</span>
              <div class="text-base-content/80 leading-relaxed">
                {Enum.join(Enum.sort(@strategy_pools.main_numbers.hot), ", ")}
              </div>
            </div>
            <div class="flex flex-col gap-0.5">
              <span class="font-semibold text-info">Cold:</span>
              <div class="text-base-content/80 leading-relaxed">
                {Enum.join(Enum.sort(@strategy_pools.main_numbers.cold), ", ")}
              </div>
            </div>
            <div class="flex flex-col gap-0.5">
              <span class="font-medium text-base-content/60">Random:</span>
              <div class="text-base-content/60">
                {length(@strategy_pools.main_numbers.random)} liczb (pozostałe)
              </div>
            </div>
          </div>
        </div>
        <div class="bg-base-100/70 p-3 rounded-lg space-y-2.5">
          <div class="font-semibold text-warning text-sm flex items-center gap-2">
            <div class="w-2.5 h-2.5 rounded-full bg-warning"></div>
            <span>Liczby Euro (1-12)</span>
          </div>
          <div class="space-y-2 pl-4 text-xs">
            <div class="flex flex-col gap-0.5">
              <span class="font-semibold text-warning/80">Hot:</span>
              <div class="text-base-content/80 leading-relaxed">
                {Enum.join(Enum.sort(@strategy_pools.euro_numbers.hot), ", ")}
              </div>
            </div>
            <div class="flex flex-col gap-0.5">
              <span class="font-medium text-base-content/60">Random:</span>
              <div class="text-base-content/60">
                {length(@strategy_pools.euro_numbers.random)} liczb (pozostałe)
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp simulation_options_form(assigns) do
    ~H"""
    <div class="space-y-3">
      <%!-- Parametry podstawowe --%>
      <div class="bg-base-100/50 p-4 rounded-lg border border-base-300/50">
        <div class="flex items-center gap-2 mb-3">
          <.icon name="hero-cog-6-tooth" class="size-4 text-primary" />
          <h4 class="font-semibold text-sm">Parametry symulacji</h4>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="form-control">
            <label class="label mb-1.5">
              <span class="label-text text-sm font-medium">Maksymalna liczba prób</span>
            </label>
            <input
              type="number"
              name="max_attempts"
              class="input input-bordered w-full input-sm"
              placeholder="10000000"
              min="1000"
              max="999999999"
            />
            <label class="label py-1">
              <span class="label-text-alt text-xs text-base-content/60">
                Domyślnie: 10,000,000
              </span>
            </label>
          </div>

          <div class="form-control">
            <label class="label mb-1.5">
              <span class="label-text text-sm font-medium">Timeout (sekundy)</span>
            </label>
            <input
              type="number"
              name="timeout_seconds"
              class="input input-bordered w-full input-sm"
              placeholder="3600"
              min="10"
              max="86400"
            />
            <label class="label py-1">
              <span class="label-text-alt text-xs text-base-content/60">
                Domyślnie: 3600s (1 godz.)
              </span>
            </label>
          </div>
        </div>
      </div>
      <%!-- Opcje zaawansowane --%>
      <details class="collapse collapse-arrow bg-base-100/30 border border-base-300/50 rounded-lg hover:bg-base-100/50 transition-colors duration-200">
        <summary class="collapse-title font-semibold text-sm min-h-0 py-3">
          <.icon name="hero-adjustments-horizontal" class="size-4 inline mr-2 text-primary" />
          Opcje zaawansowane
        </summary>
        <div class="collapse-content space-y-3 pt-2 pb-4">
          <div class="bg-base-100 p-3 rounded-lg border border-base-300/70 hover:border-primary/30 transition-colors duration-200">
            <label class="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox"
                id="half_random_mode_checkbox"
                name="half_random_mode"
                value="true"
                class="checkbox checkbox-primary checkbox-sm mt-0.5"
                phx-hook="HalfRandomMode"
              />
              <div class="flex-1">
                <div class="font-semibold text-sm mb-1">Losowo pomin połowę</div>
                <div class="text-xs text-base-content/70 leading-relaxed">
                  Redukuje pulę liczb głównych z 50 do 25 przed generowaniem kombinacji
                </div>
              </div>
            </label>
          </div>

          <div class="bg-warning/10 p-3 rounded-lg border border-warning/30 hover:border-warning/50 transition-colors duration-200">
            <label class="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox"
                id="vip1_mode_checkbox"
                name="vip1_mode"
                value="true"
                class="checkbox checkbox-warning checkbox-sm mt-0.5"
              />
              <div class="flex-1">
                <div class="font-semibold text-warning text-sm mb-1.5 flex items-center gap-2">
                  🎰 Tryb VIP1
                </div>
                <div class="text-xs text-base-content/80 space-y-1 leading-relaxed">
                  <p>Symulacja VIP1: losowo pomiń 50% liczb (25 głównych, 6 euro)</p>
                  <p class="font-medium mt-1.5">Wymagania:</p>
                  <ul class="list-disc list-inside pl-1.5 space-y-0.5">
                    <li>Max 2 liczby w jednej dziesiątce</li>
                    <li>2 nieparzyste + 3 parzyste dla głównych</li>
                  </ul>
                  <div class="mt-2 p-2 bg-warning/20 rounded text-xs font-medium">
                    ⚠️ Uwaga: Jeśli wylosowany zestaw nie zawiera poszukiwanych liczb, symulacja zwróci błąd - ponów próbę!
                  </div>
                </div>
              </div>
            </label>
          </div>
        </div>
      </details>
    </div>
    """
  end

  # ============================================================================
  # Simulations Table
  # ============================================================================

  attr :simulations, :list, required: true
  attr :live_attempts, :map, default: %{}
  attr :live_prize_tiers, :map, default: %{}
  attr :strategy_pools, :map, default: %{}

  defp simulations_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-zebra w-full text-sm">
        <thead>
          <tr>
            <th class="w-32">Strategia</th>
            <th class="w-40">Zasady</th>
            <th class="w-44">Pula liczb</th>
            <th class="w-52">Target (Poszukiwane liczby)</th>
            <th class="w-32">Data utworzenia</th>
            <th class="w-24 text-right">Liczba prób</th>
            <th class="w-24">Status</th>
            <th class="min-w-[18rem]">Wyniki nagród</th>
            <th class="w-36">Akcje</th>
          </tr>
        </thead>
        <tbody>
          <%= for sim <- @simulations do %>
            <.simulation_row
              simulation={sim}
              live_attempts={@live_attempts}
              live_prize_tiers={@live_prize_tiers}
              strategy_pools={@strategy_pools}
            />
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  # ============================================================================
  # Simulation Row & Helpers (shortened for brevity)
  # ============================================================================

  attr :simulation, :map, required: true
  attr :live_attempts, :map, required: true
  attr :live_prize_tiers, :map, required: true
  attr :strategy_pools, :map, required: true

  defp simulation_row(assigns) do
    ~H"""
    <tr class="align-top">
      <td class="font-medium w-32">
        <div class="flex flex-col gap-1">
          <span
            class="truncate text-xs"
            title={
              if Ecto.assoc_loaded?(@simulation.strategy) && @simulation.strategy,
                do: @simulation.strategy.name,
                else: "—"
            }
          >
            {if Ecto.assoc_loaded?(@simulation.strategy) && @simulation.strategy,
              do: @simulation.strategy.name,
              else: "—"}
          </span>
          <%= if @simulation.options && @simulation.options["vip1_mode"] do %>
            <span class="badge badge-warning badge-xs">🎰 VIP1</span>
          <% end %>
        </div>
      </td>
      <td class="w-40">
        <%= if @strategy_pools && Map.has_key?(@strategy_pools, @simulation.id) do %>
          {pools = Map.get(@strategy_pools, @simulation.id)
          render_strategy_pools(pools)}
        <% else %>
          <span class="text-base-content/40">—</span>
        <% end %>
      </td>
      <td class="w-44">
        <.render_numbers_pool simulation={@simulation} />
      </td>
      <td class="w-52">
        <%= if Ecto.assoc_loaded?(@simulation.target_draw) && @simulation.target_draw do %>
          <div class="space-y-1">
            <div class="flex flex-wrap gap-1">
              <.number_ball
                numbers={@simulation.target_draw.numbers.main_numbers}
                type="main"
                size="xs"
              />
            </div>
            <div class="flex flex-wrap gap-1">
              <.number_ball
                numbers={@simulation.target_draw.numbers.euro_numbers}
                type="euro"
                size="xs"
              />
            </div>
            <div class="text-xs text-base-content/60">
              ({Calendar.strftime(@simulation.target_draw.draw_date, "%Y-%m-%d")})
            </div>
          </div>
        <% else %>
          <span class="text-base-content/40">—</span>
        <% end %>
      </td>
      <td class="w-32">
        <span class="text-xs whitespace-nowrap">
          {Calendar.strftime(@simulation.inserted_at, "%Y-%m-%d %H:%M")}
        </span>
      </td>
      <td class="w-24 text-right">
        <span class="font-mono text-xs whitespace-nowrap">
          {cond do
            @simulation.status == "running" && @live_attempts ->
              sim_id_string = to_string(@simulation.id)

              if Map.has_key?(@live_attempts, sim_id_string) do
                attempts = Map.get(@live_attempts, sim_id_string)
                format_number(attempts)
              else
                if @simulation.attempts_count && @simulation.attempts_count > 0 do
                  format_number(@simulation.attempts_count)
                else
                  "—"
                end
              end

            @simulation.attempts_count && @simulation.attempts_count > 0 ->
              format_number(@simulation.attempts_count)

            true ->
              "—"
          end}
        </span>
      </td>
      <td class="w-24">
        <div class="flex flex-col gap-1">
          <.status_indicator status={@simulation.status} />
          <%= if @simulation.status == "error" && @simulation.result && @simulation.result.error_message do %>
            <div
              class="text-xs text-error mt-1 max-w-[6rem] truncate"
              title={@simulation.result.error_message}
            >
              {@simulation.result.error_message}
            </div>
          <% end %>
        </div>
      </td>
      <td class="min-w-[18rem]">
        <.prize_tiers_display simulation={@simulation} live_prize_tiers={@live_prize_tiers} />
      </td>
      <td class="w-36">
        <.simulation_actions simulation={@simulation} />
      </td>
    </tr>
    """
  end

  attr :simulation, :map, required: true
  attr :live_prize_tiers, :map, required: true

  defp prize_tiers_display(assigns) do
    ~H"""
    <%= cond do %>
      <% @simulation.status == "running" && @live_prize_tiers -> %>
        <% sim_id_string = to_string(@simulation.id) %>
        <%= if Map.has_key?(@live_prize_tiers, sim_id_string) do %>
          <% prize_tiers = Map.get(@live_prize_tiers, sim_id_string) %>
          <div class="grid grid-cols-2 gap-x-2 gap-y-1">
            <%= for tier <- 1..12 do %>
              <% count = Map.get(prize_tiers, tier, 0) %>
              <div class={[
                "flex items-center justify-between px-2 py-0.5 rounded text-xs",
                if(count > 0,
                  do: "bg-warning/20 text-warning font-semibold animate-pulse",
                  else: "bg-base-200/50 text-base-content/40"
                )
              ]}>
                <span class="font-mono">{tier}°{format_prize_description(tier)}</span>
                <span class="font-bold ml-2">{count}</span>
              </div>
            <% end %>
          </div>
        <% else %>
          <span class="text-base-content/40">—</span>
        <% end %>
      <% @simulation.status in ["success", "max_attempts_reached", "timeout"] && @simulation.result && @simulation.result.prize_tiers -> %>
        <div class="grid grid-cols-2 gap-x-2 gap-y-1">
          <%= for tier <- 1..12 do %>
            <% tier_key = Integer.to_string(tier) %>
            <% count = Map.get(@simulation.result.prize_tiers, tier_key, 0) %>
            <div class={[
              "flex items-center justify-between px-2 py-0.5 rounded text-xs",
              if(count > 0,
                do: "bg-primary/20 text-primary font-semibold",
                else: "bg-base-200/50 text-base-content/40"
              )
            ]}>
              <span class="font-mono">{tier}°{format_prize_description(tier)}</span>
              <span class="font-bold ml-2">{count}</span>
            </div>
          <% end %>
        </div>
      <% true -> %>
        <span class="text-base-content/40">—</span>
    <% end %>
    """
  end

  attr :simulation, :map, required: true

  defp simulation_actions(assigns) do
    ~H"""
    <div class="flex flex-col gap-1">
      <button
        phx-click="show_simulation_details"
        phx-value-id={@simulation.id}
        class="btn btn-xs btn-ghost justify-start"
        title="Pokaż pełne szczegóły: pulę, nagrody, trafienia"
      >
        <.icon name="hero-eye" class="size-3" />
        <span class="text-xs">Szczegóły</span>
      </button>
      <%= if @simulation.status == "max_attempts_reached" do %>
        <button
          phx-click="show_update_max_attempts"
          phx-value-id={@simulation.id}
          class="btn btn-xs btn-warning justify-start"
          title="Zmień limit prób"
        >
          <.icon name="hero-cog-6-tooth" class="size-3" />
          <span class="text-xs">↑ Limit</span>
        </button>
      <% end %>
      <%= if @simulation.status == "timeout" do %>
        <button
          phx-click="show_update_timeout"
          phx-value-id={@simulation.id}
          class="btn btn-xs btn-warning justify-start"
          title="Zmień timeout"
        >
          <.icon name="hero-cog-6-tooth" class="size-3" />
          <span class="text-xs">↑ Czas</span>
        </button>
      <% end %>
      <button
        phx-click="toggle_favorite"
        phx-value-id={@simulation.id}
        class={[
          "btn btn-xs justify-start",
          if(@simulation.is_favorite, do: "btn-warning", else: "btn-ghost")
        ]}
        title={if @simulation.is_favorite, do: "Odznacz jako ulubioną", else: "Oznacz jako ulubioną"}
      >
        <.icon
          name={if @simulation.is_favorite, do: "hero-star-solid", else: "hero-star"}
          class="size-3"
        />
        {if @simulation.is_favorite, do: "Oznaczona", else: "Oznacz"}
      </button>
      <%= if @simulation.status == "running" do %>
        <button
          phx-click="stop_simulation"
          phx-value-id={@simulation.id}
          class="btn btn-xs btn-warning justify-start"
          title="Zatrzymaj symulację"
        >
          <.icon name="hero-stop" class="size-3" />
          <span class="text-xs">Stop</span>
        </button>
      <% end %>
      <%= if @simulation.status == "cancelled" do %>
        <button
          phx-click="resume_simulation"
          phx-value-id={@simulation.id}
          class="btn btn-xs btn-success justify-start"
          title="Wznów zatrzymaną symulację"
        >
          <.icon name="hero-play" class="size-3" />
          <span class="text-xs">Wznów</span>
        </button>
      <% end %>
      <%= if @simulation.status not in ["running", "cancelled"] do %>
        <button
          phx-click="show_restart_simulation"
          phx-value-id={@simulation.id}
          class="btn btn-xs btn-primary justify-start"
          title="Uruchom ponownie z nowymi ustawieniami"
        >
          <.icon name="hero-play" class="size-3" />
          <span class="text-xs">Restart</span>
        </button>
      <% end %>
      <button
        phx-click="delete_simulation"
        phx-value-id={@simulation.id}
        class="btn btn-xs btn-error justify-start"
        title="Usuń symulację"
        data-confirm="Czy na pewno chcesz usunąć tę symulację?"
      >
        <.icon name="hero-trash" class="size-3" />
        <span class="text-xs">Usuń</span>
      </button>
    </div>
    """
  end

  # ============================================================================
  # Pool Display & Helpers (VIP1, VIP2, blacklist)
  # ============================================================================

  attr :simulation, :map, required: true

  defp render_numbers_pool(assigns) do
    pool_data = get_pool_data(assigns.simulation)
    assigns = assign(assigns, :pool_data, pool_data)

    ~H"""
    <%= case @pool_data do %>
      <% {:vip1, main_pool, euro_pool} -> %>
        <div class="text-xs space-y-1">
          <div class="font-semibold text-warning">🎰 VIP1</div>
          <div class="space-y-0.5">
            <div>
              <span class="font-medium text-error">M ({length(main_pool)}):</span>
            </div>
            <div class="text-base-content/70 text-[0.6rem] leading-tight">
              {Enum.sort(main_pool) |> Enum.join(", ")}
            </div>
            <div>
              <span class="font-medium text-warning">E ({length(euro_pool)}):</span>
            </div>
            <div class="text-base-content/70 text-[0.6rem] leading-tight">
              {Enum.sort(euro_pool) |> Enum.join(", ")}
            </div>
          </div>
        </div>
      <% {:vip2, main_available, euro_available, _main_blacklist, _euro_blacklist} -> %>
        <div class="text-xs space-y-1">
          <div class="font-semibold text-secondary">🎲 VIP2</div>
          <div class="space-y-0.5">
            <div>
              <span class="font-medium text-error">M ({length(main_available)}):</span>
            </div>
            <div class="text-base-content/70 text-[0.6rem] leading-tight">
              {Enum.sort(main_available) |> Enum.take(15) |> Enum.join(", ")}{if length(
                                                                                   main_available
                                                                                 ) > 15,
                                                                                 do: "...",
                                                                                 else: ""}
            </div>
            <div>
              <span class="font-medium text-warning">E ({length(euro_available)}):</span>
            </div>
            <div class="text-base-content/70 text-[0.6rem] leading-tight">
              {Enum.sort(euro_available) |> Enum.join(", ")}
            </div>
          </div>
        </div>
      <% {:blacklist, main_available, euro_available, _main_blacklist, _euro_blacklist} -> %>
        <div class="text-xs space-y-1">
          <div class="font-semibold text-info">📋 Blacklist</div>
          <div class="space-y-0.5">
            <div>
              <span class="font-medium text-error">M ({length(main_available)}):</span>
            </div>
            <div class="text-base-content/70 text-[0.6rem] leading-tight">
              {Enum.sort(main_available) |> Enum.take(15) |> Enum.join(", ")}{if length(
                                                                                   main_available
                                                                                 ) > 15,
                                                                                 do: "...",
                                                                                 else: ""}
            </div>
            <div>
              <span class="font-medium text-warning">E ({length(euro_available)}):</span>
            </div>
            <div class="text-base-content/70 text-[0.6rem] leading-tight">
              {Enum.sort(euro_available) |> Enum.join(", ")}
            </div>
          </div>
        </div>
      <% :full -> %>
        <span class="text-base-content/40 text-xs whitespace-nowrap">Pełna (50+12)</span>
    <% end %>
    """
  end

  defp get_pool_data(sim) do
    get_vip1_pool(sim) || get_vip2_pool(sim) || get_blacklist_pool(sim) || :full
  end

  defp get_vip1_pool(%{options: %{"vip1_pool" => pool}}) when not is_nil(pool) do
    {:vip1, pool["main_pool"] || [], pool["euro_pool"] || []}
  end

  defp get_vip1_pool(_), do: nil

  defp get_vip2_pool(%{options: %{"vip2_blacklist" => blacklist}}) when not is_nil(blacklist) do
    main_bl = blacklist["main_blacklist"] || []
    euro_bl = blacklist["euro_blacklist"] || []
    main_available = Enum.reject(1..50, &(&1 in main_bl))
    euro_available = Enum.reject(1..12, &(&1 in euro_bl))
    {:vip2, main_available, euro_available, main_bl, euro_bl}
  end

  defp get_vip2_pool(_), do: nil

  defp get_blacklist_pool(%{strategy: strategy}) when not is_nil(strategy) do
    if Ecto.assoc_loaded?(strategy) and has_blacklist?(strategy) do
      main_bl = strategy.rules.main_numbers.blacklist || []
      euro_bl = strategy.rules.euro_numbers.blacklist || []
      main_available = Enum.reject(1..50, &(&1 in main_bl))
      euro_available = Enum.reject(1..12, &(&1 in euro_bl))
      {:blacklist, main_available, euro_available, main_bl, euro_bl}
    end
  end

  defp get_blacklist_pool(_), do: nil

  defp has_blacklist?(strategy) do
    main_bl = strategy.rules.main_numbers.blacklist || []
    euro_bl = strategy.rules.euro_numbers.blacklist || []
    length(main_bl) > 0 or length(euro_bl) > 0
  end

  defp vip_strategy?(%{name: name}) do
    name_upper = String.upcase(name)
    String.contains?(name_upper, "VIP1") or String.contains?(name_upper, "VIP2")
  end

  defp vip_strategy?(_), do: false

  defp render_strategy_pools(pools) do
    main_pools = pools.main_numbers
    euro_pools = pools.euro_numbers
    # Calculate actual pool size
    main_total = length(main_pools.hot) + length(main_pools.cold) + length(main_pools.random)
    euro_total = length(euro_pools.hot) + length(euro_pools.random)

    assigns = %{
      main_pools: main_pools,
      euro_pools: euro_pools,
      main_total: main_total,
      euro_total: euro_total
    }

    ~H"""
    <div class="text-xs space-y-1">
      <div class="flex flex-col gap-0.5">
        <div class="flex items-start gap-1">
          <span class="font-semibold text-error min-w-[2.2rem]">Hot:</span>
          <span class="flex-1 text-[0.65rem]">{Enum.join(Enum.sort(@main_pools.hot), ", ")}</span>
        </div>
        <div class="flex items-start gap-1">
          <span class="font-semibold text-info min-w-[2.2rem]">Cold:</span>
          <span class="flex-1 text-[0.65rem]">{Enum.join(Enum.sort(@main_pools.cold), ", ")}</span>
        </div>
        <div class="flex items-start gap-1">
          <span class="font-semibold text-base-content/60 min-w-[2.2rem]">Rand:</span>
          <span class="flex-1">{length(@main_pools.random)}</span>
        </div>
        <div class="text-[0.6rem] text-base-content/50 mt-0.5">
          {@main_total} liczb
        </div>
      </div>
      <div class="pt-1 border-t border-base-300 flex flex-col gap-0.5">
        <div class="flex items-start gap-1">
          <span class="font-semibold text-warning min-w-[2.2rem]">E-Hot:</span>
          <span class="flex-1 text-[0.65rem]">{Enum.join(Enum.sort(@euro_pools.hot), ", ")}</span>
        </div>
        <div class="flex items-start gap-1">
          <span class="font-semibold text-base-content/60 min-w-[2.2rem]">E-Rnd:</span>
          <span class="flex-1">{length(@euro_pools.random)}</span>
        </div>
        <div class="text-[0.6rem] text-base-content/50 mt-0.5">
          {@euro_total} liczb
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Simulation Details Modal
  # ============================================================================

  @doc """
  Modal for displaying detailed simulation results.
  """
  attr :simulation, :map, required: true
  attr :show, :boolean, default: false

  def simulation_details_modal(assigns) do
    ~H"""
    <dialog class={["modal", @show && "modal-open"]}>
      <div class="modal-box max-w-2xl">
        <h3 class="font-bold text-lg mb-4">Szczegóły symulacji</h3>

        <%= if @simulation do %>
          <div class="space-y-4">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <span class="font-semibold">Strategia:</span>
                <span class="ml-2">
                  {if Ecto.assoc_loaded?(@simulation.strategy) && @simulation.strategy,
                    do: @simulation.strategy.name,
                    else: "—"}
                </span>
              </div>
              <div>
                <span class="font-semibold">Status:</span>
                <span class="ml-2">
                  <.status_indicator status={@simulation.status} />
                </span>
              </div>
              <div>
                <span class="font-semibold">Liczba prób:</span>
                <span class="ml-2 font-mono">
                  {NumbersEvolutionWeb.SharedComponents.format_number(@simulation.attempts_count || 0)}
                </span>
              </div>
              <div>
                <span class="font-semibold">Czas trwania:</span>
                <span class="ml-2 font-mono">
                  {NumbersEvolutionWeb.SharedComponents.format_duration(
                    @simulation.duration_seconds || 0
                  )}
                </span>
              </div>
            </div>

            <.render_pool_details_modal simulation={@simulation} />

            <%= if Ecto.assoc_loaded?(@simulation.target_draw) && @simulation.target_draw do %>
              <div class="border-t border-base-300 pt-4">
                <h4 class="font-semibold mb-2">Poszukiwane liczby</h4>
                <div class="flex gap-4">
                  <div>
                    <span class="text-sm font-semibold">Główne:</span>
                    <div class="flex gap-1 mt-1">
                      <.number_ball
                        numbers={@simulation.target_draw.numbers.main_numbers}
                        type="main"
                        size="sm"
                      />
                    </div>
                  </div>
                  <div>
                    <span class="text-sm font-semibold">Euro:</span>
                    <div class="flex gap-1 mt-1">
                      <.number_ball
                        numbers={@simulation.target_draw.numbers.euro_numbers}
                        type="euro"
                        size="sm"
                      />
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if @simulation.result && @simulation.result.prize_tiers do %>
              <div class="border-t border-base-300 pt-4">
                <h4 class="font-semibold mb-3">Wyniki nagród</h4>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <%= for tier <- 1..12 do %>
                    <% tier_key = Integer.to_string(tier) %>
                    <% count = Map.get(@simulation.result.prize_tiers, tier_key, 0) %>
                    <div class={[
                      "p-4 rounded-lg border",
                      if(count > 0,
                        do: "border-primary bg-primary/5",
                        else: "border-base-300 bg-base-200"
                      )
                    ]}>
                      <div class="flex items-center justify-between mb-2">
                        <div class="flex flex-col">
                          <span class="font-semibold text-sm">
                            {tier}° nagroda {NumbersEvolutionWeb.SharedComponents.format_prize_description(
                              tier
                            )}
                          </span>
                        </div>
                        <div class="text-right">
                          <span class={[
                            "font-bold text-lg",
                            if(count > 0, do: "text-primary", else: "text-base-content/40")
                          ]}>
                            {count}
                          </span>
                        </div>
                      </div>

                      <%= if tier in 1..5 and count > 0 and @simulation.result.prize_details && Map.get(@simulation.result.prize_details, tier_key) do %>
                        <% tier_details = Map.get(@simulation.result.prize_details, tier_key, []) %>
                        <div class="mt-3 space-y-2">
                          <span class="text-xs font-semibold text-base-content/70">
                            Trafione liczby:
                          </span>
                          <%= for detail <- tier_details |> Enum.take(5) do %>
                            <div class="flex gap-3 text-xs">
                              <div class="flex items-center gap-1">
                                <span class="text-base-content/60">Główne:</span>
                                <div class="flex gap-1">
                                  <%= for num <- detail.main_numbers |> Enum.sort() do %>
                                    <span class="badge badge-xs badge-outline">{num}</span>
                                  <% end %>
                                </div>
                              </div>
                              <div class="flex items-center gap-1">
                                <span class="text-base-content/60">Euro:</span>
                                <div class="flex gap-1">
                                  <%= for num <- detail.euro_numbers |> Enum.sort() do %>
                                    <span class="badge badge-xs badge-outline">{num}</span>
                                  <% end %>
                                </div>
                              </div>
                            </div>
                          <% end %>
                          <%= if length(tier_details) > 5 do %>
                            <span class="text-xs text-base-content/50">
                              ... i {length(tier_details) - 5} więcej
                            </span>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <div class="mt-4 p-3 bg-base-200 rounded-lg">
                  <div class="flex justify-between items-center">
                    <span class="font-semibold">Razem trafionych nagród:</span>
                    <span class="font-bold text-lg text-primary">
                      {@simulation.result.prize_tiers
                      |> Enum.filter(fn {k, _v} -> is_integer(k) end)
                      |> Enum.map(fn {_k, v} -> v end)
                      |> Enum.sum()}
                    </span>
                  </div>
                  <%= if @simulation.result.prize_tiers[1] && @simulation.result.prize_tiers[1] > 0 do %>
                    <div class="flex justify-between items-center mt-1">
                      <span class="text-sm">W tym jackpotów:</span>
                      <span class="font-bold text-lg text-success">
                        {@simulation.result.prize_tiers[1]}
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if @simulation.status == "success" && @simulation.result && @simulation.result.matched_main do %>
              <div class="border-t border-base-300 pt-4">
                <h4 class="font-semibold mb-2">Ostateczne trafienie</h4>
                <div class="flex gap-4">
                  <div>
                    <span class="text-sm font-semibold">Główne:</span>
                    <div class="flex gap-1 mt-1">
                      <.number_ball numbers={@simulation.result.matched_main} type="main" size="sm" />
                    </div>
                  </div>
                  <div>
                    <span class="text-sm font-semibold">Euro:</span>
                    <div class="flex gap-1 mt-1">
                      <.number_ball numbers={@simulation.result.matched_euro} type="euro" size="sm" />
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <div class="modal-action">
          <button phx-click="close_simulation_details" class="btn">Zamknij</button>
        </div>
      </div>
    </dialog>
    """
  end

  defp render_pool_details_modal(assigns) do
    sim = assigns.simulation
    pool_data = get_pool_data(sim)
    assigns = assign(assigns, :pool_data, pool_data)

    ~H"""
    <%= case @pool_data do %>
      <% {:vip1, main_pool, euro_pool} -> %>
        <div class="border-t border-base-300 pt-4">
          <div class="alert alert-warning">
            <span class="text-lg">🎰</span>
            <div>
              <h4 class="font-bold">Pula liczb (VIP1 - losowa)</h4>
              <p class="text-sm">
                Losowo pominięto 50% liczb. Warunki: max 2 w dziesiątce, 2 nieparzyste + 3 parzyste.
              </p>
            </div>
          </div>
          <div class="mt-3 bg-base-200 p-4 rounded-lg">
            <h5 class="font-semibold mb-2">Startowy zestaw:</h5>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <span class="text-sm font-semibold text-error">
                  Główne ({length(main_pool)} z 50):
                </span>
                <div class="flex flex-wrap gap-1 mt-1">
                  <%= for num <- main_pool |> Enum.sort() do %>
                    <span class="badge badge-sm badge-outline">{num}</span>
                  <% end %>
                </div>
              </div>
              <div>
                <span class="text-sm font-semibold text-warning">
                  Euro ({length(euro_pool)} z 12):
                </span>
                <div class="flex flex-wrap gap-1 mt-1">
                  <%= for num <- euro_pool |> Enum.sort() do %>
                    <span class="badge badge-sm badge-outline">{num}</span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% {:vip2, _main_available, euro_available, main_blacklist, _euro_blacklist} -> %>
        <div class="border-t border-base-300 pt-4">
          <div class="alert alert-secondary">
            <span class="text-lg">🎲</span>
            <div>
              <h4 class="font-bold">Pula liczb (VIP2 - auto-blacklist)</h4>
              <p class="text-sm">
                Automatycznie wykluczono {length(main_blacklist)} głównych i {12 -
                  length(euro_available)} euro liczb.
              </p>
            </div>
          </div>
        </div>
      <% {:blacklist, _main_available, euro_available, main_blacklist, _euro_blacklist} -> %>
        <div class="border-t border-base-300 pt-4">
          <div class="alert alert-info">
            <span class="text-lg">📋</span>
            <div>
              <h4 class="font-bold">Pula liczb (stała - blacklist)</h4>
              <p class="text-sm">
                Strategia wyklucza {length(main_blacklist)} głównych i {12 - length(euro_available)} euro liczb.
              </p>
            </div>
          </div>
        </div>
      <% :full -> %>
    <% end %>
    """
  end
end
