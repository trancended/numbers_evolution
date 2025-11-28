defmodule NumbersEvolutionWeb.SectionsComponents do
  @moduledoc """
  Function components for advanced sections (strategies, simulations, ranking, generator).
  Separated from PageComponents for better organization.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents
  alias Phoenix.LiveView.JS

  # ============================================================================
  # Strategies Section
  # ============================================================================

  @doc """
  Renders the strategies management section.
  """
  attr(:strategies, :list, required: true)
  attr(:show_strategy_form, :boolean, required: true)
  attr(:strategy_form_tab, :atom, required: true)
  attr(:generated_strategy, :map, default: nil)
  attr(:example_prompt, :string, default: "")

  def strategies_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex justify-between items-center">
        <h1 class="text-4xl font-bold">Moje Strategie</h1>
        <div class="flex gap-4">
          <button data-cy="create-strategy-btn" phx-click="open_strategy_form" class="btn btn-primary">
            <.icon name="hero-plus" class="size-5" /> Nowa strategia
          </button>
        </div>
      </div>

      <%= if @strategies == [] do %>
        <.empty_state icon="hero-light-bulb">
          <:title>Nie masz jeszcze strategii</:title>
          <:description>
            Opisz strategię tekstowo, a AI wygeneruje dla Ciebie reguły
          </:description>
          <:action>
            <button phx-click="open_strategy_form" class="btn btn-primary btn-lg">
              <.icon name="hero-sparkles" class="size-6" /> Utwórz pierwszą strategię
            </button>
          </:action>
        </.empty_state>
      <% else %>
        <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for strategy <- @strategies do %>
            <.strategy_card strategy={strategy} />
          <% end %>
        </div>
      <% end %>

      <%!-- Strategy Form Modal --%>
      <.modal
        data_cy="strategy-form-modal"
        id="strategy-form-modal"
        show={@show_strategy_form}
        on_cancel={JS.push("close_strategy_form")}
        size="lg"
      >
        <:title>Nowa Strategia</:title>

        <div class="tabs tabs-boxed tabs-lg mb-6">
          <button
            data-cy="ai-tab"
            phx-click="switch_strategy_tab"
            phx-value-tab="ai"
            class={["tab tab-lg font-semibold", @strategy_form_tab == :ai && "tab-active"]}
          >
            <.icon name="hero-sparkles" class="size-5 mr-2" /> AI
          </button>
          <button
            data-cy="manual-tab"
            phx-click="switch_strategy_tab"
            phx-value-tab="manual"
            class={[
              "tab tab-lg font-semibold opacity-60",
              @strategy_form_tab == :manual && "tab-active"
            ]}
            disabled
          >
            <.icon name="hero-wrench-screwdriver" class="size-5 mr-2" /> Manualna (wkrótce)
          </button>
        </div>

        <%= if @strategy_form_tab == :ai do %>
          <.ai_strategy_form
            generated_strategy={@generated_strategy}
            example_prompt={@example_prompt}
          />
        <% else %>
          <.alert kind="info">
            Formularz manualnego tworzenia strategii będzie dostępny w pełnej wersji.
            Na razie skorzystaj z generowania przez AI.
          </.alert>
        <% end %>

        <:actions>
          <button phx-click="close_strategy_form" class="btn">Zamknij</button>
        </:actions>
      </.modal>
    </div>
    """
  end

  attr(:generated_strategy, :map, default: nil)
  attr(:example_prompt, :string, default: "")

  defp ai_strategy_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @generated_strategy do %>
        <%!-- Preview wygenerowanej strategii --%>
        <.alert kind="success">
          <strong>✓ Strategia wygenerowana pomyślnie!</strong>
        </.alert>

        <div data-cy="strategy-preview" class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title flex items-center gap-2">
              <.icon name="hero-sparkles" class="size-6 text-warning" />
              {@generated_strategy.strategy_name}
            </h3>
            <p class="text-sm">{@generated_strategy.description}</p>

            <div class="divider">Uzasadnienie AI</div>
            <p class="text-sm italic text-base-content/70">{@generated_strategy.reasoning}</p>

            <div class="divider">Szczegóły Reguł</div>

            <div class="text-sm space-y-3">
              <div>
                <p class="font-semibold">Główne liczby (1-50):</p>
                <ul class="list-disc list-inside ml-4 space-y-1 text-base-content/70">
                  <li>
                    Ratio parzyste/nieparzyste: {Enum.at(
                      @generated_strategy.rules["main_numbers"]["ratio_even_odd"],
                      0
                    )} / {Enum.at(@generated_strategy.rules["main_numbers"]["ratio_even_odd"], 1)}
                  </li>
                  <li>
                    Ratio niskie/wysokie: {Enum.at(
                      @generated_strategy.rules["main_numbers"]["ratio_low_high"],
                      0
                    )} / {Enum.at(@generated_strategy.rules["main_numbers"]["ratio_low_high"], 1)}
                  </li>
                  <li>
                    Wagi: Hot {Float.round(
                      @generated_strategy.rules["main_numbers"]["weights"]["hot"] * 100,
                      0
                    )}%,
                    Cold {Float.round(
                      Map.get(@generated_strategy.rules["main_numbers"]["weights"], "cold", 0.0) * 100,
                      0
                    )}%,
                    Random {Float.round(
                      @generated_strategy.rules["main_numbers"]["weights"]["random"] * 100,
                      0
                    )}%
                  </li>
                  <%= if length(@generated_strategy.rules["main_numbers"]["blacklist"] || []) > 0 do %>
                    <li>
                      Blacklist: {length(@generated_strategy.rules["main_numbers"]["blacklist"])} liczb
                    </li>
                  <% end %>
                </ul>
              </div>

              <div>
                <p class="font-semibold">Euro liczby (1-12):</p>
                <ul class="list-disc list-inside ml-4 space-y-1 text-base-content/70">
                  <li>
                    Ratio parzyste/nieparzyste: {Enum.at(
                      @generated_strategy.rules["euro_numbers"]["ratio_even_odd"],
                      0
                    )} / {Enum.at(@generated_strategy.rules["euro_numbers"]["ratio_even_odd"], 1)}
                  </li>
                  <li>
                    Wagi: Hot {Float.round(
                      @generated_strategy.rules["euro_numbers"]["weights"]["hot"] * 100,
                      0
                    )}%,
                    Random {Float.round(
                      @generated_strategy.rules["euro_numbers"]["weights"]["random"] * 100,
                      0
                    )}%
                  </li>
                </ul>
              </div>
            </div>

            <div class="mt-4 flex gap-2">
              <button
                data-cy="save-strategy-btn"
                phx-click="create_ai_strategy"
                phx-value-prompt={@generated_strategy.strategy_name}
                class="btn btn-primary flex-1"
              >
                <.icon name="hero-check" class="size-5" /> Zapisz strategię
              </button>
              <button
                data-cy="regenerate-strategy-btn"
                phx-click="clear_generated_strategy"
                class="btn btn-ghost"
              >
                <.icon name="hero-arrow-path" class="size-5" /> Generuj ponownie
              </button>
            </div>
          </div>
        </div>
      <% else %>
        <%!-- Formularz promptu --%>
        <.alert kind="info" class="text-sm">
          <strong>Opisz strategię słowami</strong> - AI wygeneruje odpowiednie reguły typowania.
        </.alert>

        <form phx-submit="create_ai_strategy" class="space-y-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Opisz swoją strategię</span>
              <span class="label-text-alt">Min 10, max 500 znaków</span>
            </label>
            <textarea
              id="strategy-prompt-textarea"
              name="prompt"
              class="textarea textarea-bordered h-32"
              placeholder="Np. Pomin połowę liczb (wszystkie parzyste), skupiamy się tylko na nieparzystych..."
              required
              minlength="10"
              maxlength="500"
              phx-hook="SetTextareaValue"
              data-value={@example_prompt}
            >{@example_prompt}</textarea>
          </div>

          <div class="divider text-sm">Przykładowe strategie</div>

          <div class="grid md:grid-cols-2 gap-2">
            <button
              data-cy="template-tylko-nieparzyste"
              type="button"
              phx-click="use_strategy_template"
              phx-value-strategy="tylko_nieparzyste"
              class="btn btn-sm btn-outline justify-start text-left min-h-[4rem] py-3"
            >
              <div class="flex flex-col items-start gap-1">
                <div class="font-semibold text-left w-full">Tylko Nieparzyste</div>
                <div class="text-xs opacity-70 text-left w-full">Pomija wszystkie parzyste</div>
              </div>
            </button>

            <button
              data-cy="template-dwie-nieparzyste-trzy-parzyste"
              type="button"
              phx-click="use_strategy_template"
              phx-value-strategy="dwie_nieparzyste_trzy_parzyste"
              class="btn btn-sm btn-outline justify-start text-left min-h-[4rem] py-3"
            >
              <div class="flex flex-col items-start gap-1">
                <div class="font-semibold text-left w-full">2 Nieparzyste, 3 Parzyste</div>
                <div class="text-xs opacity-70 text-left w-full">Precyzyjne ratio</div>
              </div>
            </button>

            <button
              data-cy="template-max-dwie-w-dziesiatce"
              type="button"
              phx-click="use_strategy_template"
              phx-value-strategy="max_dwie_w_dziesiatce"
              class="btn btn-sm btn-outline justify-start text-left min-h-[4rem] py-3"
            >
              <div class="flex flex-col items-start gap-1">
                <div class="font-semibold text-left w-full">Max 2 w Dziesiątce</div>
                <div class="text-xs opacity-70 text-left w-full">Rozproszone liczby</div>
              </div>
            </button>

            <button
              data-cy="template-balans-hot-cold"
              type="button"
              phx-click="use_strategy_template"
              phx-value-strategy="balans_hot_cold"
              class="btn btn-sm btn-outline justify-start text-left min-h-[4rem] py-3"
            >
              <div class="flex flex-col items-start gap-1">
                <div class="font-semibold text-left w-full">Balans Hot/Cold</div>
                <div class="text-xs opacity-70 text-left w-full">Zrównoważona strategia</div>
              </div>
            </button>

            <button
              data-cy="template-ekstremalna-hot"
              type="button"
              phx-click="use_strategy_template"
              phx-value-strategy="ekstremalna_hot"
              class="btn btn-sm btn-outline justify-start text-left min-h-[4rem] py-3"
            >
              <div class="flex flex-col items-start gap-1">
                <div class="font-semibold text-left w-full">Ekstremalna Hot</div>
                <div class="text-xs opacity-70 text-left w-full">80% gorących liczb</div>
              </div>
            </button>

            <button
              data-cy="template-przeciwny-trend"
              type="button"
              phx-click="use_strategy_template"
              phx-value-strategy="przeciwny_trend"
              class="btn btn-sm btn-outline justify-start text-left min-h-[4rem] py-3"
            >
              <div class="flex flex-col items-start gap-1">
                <div class="font-semibold text-left w-full">Przeciwny Trend</div>
                <div class="text-xs opacity-70 text-left w-full">Gra na cold numbers</div>
              </div>
            </button>
          </div>

          <button data-cy="generate-strategy-btn" type="submit" class="btn btn-primary w-full mt-6">
            <.icon name="hero-sparkles" class="size-5" /> Wygeneruj strategię przez AI
          </button>
        </form>
      <% end %>
    </div>
    """
  end

  attr(:strategy, :map, required: true)

  defp strategy_card(assigns) do
    ~H"""
    <.card class="flex flex-col h-full">
      <div class="flex items-center gap-2 mb-2">
        <h3 class="font-bold text-lg">{@strategy.name}</h3>
        <.badge
          variant={if @strategy.type == :ai_generated, do: "success", else: "info"}
          size="sm"
        >
          {if @strategy.type == :ai_generated, do: "AI", else: "Manual"}
        </.badge>
      </div>

      <div class="h-16">
        <p :if={@strategy.description} class="text-sm text-base-content/70 line-clamp-3">
          {@strategy.description}
        </p>
      </div>

      <div class="stats stats-horizontal shadow w-full mb-4">
        <div class="stat p-3">
          <div class="stat-title text-xs">Performance</div>
          <div class="stat-value text-base">
            {if @strategy.performance_score,
              do: Float.round(@strategy.performance_score, 2),
              else: "—"}
          </div>
        </div>
      </div>

      <div class="flex gap-2 flex-wrap">
        <button class="btn btn-sm btn-ghost">
          <.icon name="hero-eye" class="size-4" /> Szczegóły
        </button>
        <button
          id={"delete-strategy-#{@strategy.id}"}
          type="button"
          phx-click="delete_strategy"
          phx-click.stop
          phx-value-id={@strategy.id}
          phx-hook="ConfirmDelete"
          class="btn btn-sm btn-error"
        >
          <.icon name="hero-trash" class="size-4" /> Usuń
        </button>
      </div>
    </.card>
    """
  end

  # ============================================================================
  # Simulations Section
  # ============================================================================

  @doc """
  Renders the simulations section with form and history.
  """
  attr(:strategies, :list, required: true)
  attr(:simulations, :list, required: true)
  attr(:draws, :list, required: true)
  attr(:live_attempts, :map, default: %{})
  attr(:strategy_pools, :map, default: %{})
  attr(:selected_strategy, :any, default: nil)
  attr(:target_validation_error, :string, default: nil)

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
            <:description>
              Uruchom swoją pierwszą symulację, aby przetestować strategię
            </:description>
          </.empty_state>
        <% else %>
          <.simulations_table
            simulations={@simulations}
            live_attempts={@live_attempts}
            strategy_pools={@strategy_pools}
          />
        <% end %>
      </.card>
    </div>
    """
  end

  attr(:strategies, :list, required: true)
  attr(:draws, :list, required: true)
  attr(:selected_strategy, :any, default: nil)
  attr(:strategy_pools, :map, default: %{})
  attr(:target_validation_error, :string, default: nil)

  defp simulation_form(assigns) do
    ~H"""
    <form phx-submit="start_simulation" class="space-y-4">
      <div class="form-control mt-6">
        <label class="label mb-3">
          <span class="label-text">Wybierz strategię</span>
        </label>
        <select
          data-cy="strategy-select"
          name="strategy_id"
          class="select select-bordered"
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
        <label class="label mb-3">
          <span class="label-text">Target draw (losowanie docelowe)</span>
        </label>
        <select
          data-cy="target-draw-select"
          name="target_draw_id"
          class="select select-bordered"
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
      </div>

      <%= if @selected_strategy do %>
        <div class="bg-base-200 p-4 rounded-lg">
          <h4 class="font-semibold mb-2">Komplet liczb strategii "{@selected_strategy.name}"</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
            <div>
              <div class="font-medium text-error mb-1">Główne liczby (1-50):</div>
              <div class="space-y-1">
                <div>
                  <span class="font-medium">Hot:</span> {Enum.join(
                    Enum.sort(@strategy_pools.main_numbers.hot),
                    ", "
                  )}
                </div>
                <div>
                  <span class="font-medium">Cold:</span> {Enum.join(
                    Enum.sort(@strategy_pools.main_numbers.cold),
                    ", "
                  )}
                </div>
                <div>
                  <span class="font-medium">Random:</span> {length(
                    @strategy_pools.main_numbers.random
                  )} liczb (pozostałe)
                </div>
              </div>
            </div>
            <div>
              <div class="font-medium text-warning mb-1">Liczby Euro (1-12):</div>
              <div class="space-y-1">
                <div>
                  <span class="font-medium">Hot:</span> {Enum.join(
                    Enum.sort(@strategy_pools.euro_numbers.hot),
                    ", "
                  )}
                </div>
                <div>
                  <span class="font-medium">Random:</span> {length(
                    @strategy_pools.euro_numbers.random
                  )} liczb (pozostałe)
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @target_validation_error do %>
        <div class="alert alert-warning">
          <span class="hero-exclamation-triangle size-5 shrink-0"></span>
          <div>
            <p class="font-semibold">Komplet liczb nie pasuje do symulacji</p>
            <p>{@target_validation_error}</p>
          </div>
        </div>
      <% end %>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="form-control">
          <label class="label mb-3">
            <span class="label-text">Maksymalna liczba prób</span>
          </label>
          <input
            type="number"
            name="max_attempts"
            class="input input-bordered"
            placeholder="999999999"
            min="1000"
            max="999999999"
          />
          <label class="label">
            <span class="label-text-alt text-sm font-normal">Domyślnie: 999,999,999</span>
          </label>
        </div>

        <div class="form-control">
          <label class="label mb-3">
            <span class="label-text">Timeout (sekundy)</span>
          </label>
          <input
            type="number"
            name="timeout_seconds"
            class="input input-bordered"
            placeholder="86400"
            min="10"
            max="86400"
          />
          <label class="label">
            <span class="label-text-alt text-sm font-normal">Domyślnie: 86400s (24 godziny)</span>
          </label>
        </div>
      </div>

      <details class="collapse collapse-arrow bg-base-100">
        <summary class="collapse-title font-medium">
          Opcje zaawansowane
        </summary>
        <div class="collapse-content space-y-4">
          <div class="form-control">
            <label class="label cursor-pointer">
              <input
                type="checkbox"
                id="half_random_mode_checkbox"
                name="half_random_mode"
                value="true"
                class="checkbox checkbox-primary"
                phx-hook="HalfRandomMode"
              />
              <span class="label-text ml-2">Losowo pomin połowę</span>
            </label>
            <label class="label">
              <span class="label-text-alt">
                Redukuje pulę liczb głównych z 50 do 25 przed generowaniem kombinacji
              </span>
            </label>
          </div>
        </div>
      </details>

      <button data-cy="start-simulation-btn" type="submit" class="btn btn-primary w-full">
        <.icon name="hero-play" class="size-5" /> Uruchom symulację
      </button>
    </form>
    """
  end

  attr(:simulations, :list, required: true)
  attr(:live_attempts, :map, default: %{})
  attr(:strategy_pools, :map, default: %{})

  defp simulations_table(assigns) do
    ~H"""
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
          <%= for sim <- @simulations do %>
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
                      if sim.is_favorite, do: "Odznacz jako ulubioną", else: "Oznacz jako ulubioną"
                    }
                  >
                    <.icon
                      name={if sim.is_favorite, do: "hero-star-solid", else: "hero-star"}
                      class="size-4"
                    />
                    {if sim.is_favorite, do: "Oznaczona", else: "Oznacz"}
                  </button>
                  <%= if sim.status == "running" do %>
                    <button
                      phx-click="stop_simulation"
                      phx-value-id={sim.id}
                      class="btn btn-sm btn-warning"
                      title="Zatrzymaj symulację"
                    >
                      <.icon name="hero-stop" class="size-4" /> {"Zatrzymaj"}
                    </button>
                  <% end %>
                  <%= if sim.status == "cancelled" do %>
                    <button
                      phx-click="resume_simulation"
                      phx-value-id={sim.id}
                      class="btn btn-sm btn-success"
                      title="Wznów zatrzymaną symulację"
                    >
                      <.icon name="hero-play" class="size-4" /> {"Wznów"}
                    </button>
                  <% end %>
                  <%= if sim.status not in ["running", "cancelled"] do %>
                    <button
                      phx-click="show_restart_simulation"
                      phx-value-id={sim.id}
                      class="btn btn-sm btn-primary"
                      title="Uruchom ponownie z nowymi ustawieniami"
                    >
                      <.icon name="hero-play" class="size-4" /> {"Uruchom ponownie"}
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

  # ============================================================================
  # Ranking Section
  # ============================================================================

  @doc """
  Renders the ranking section with strategies sorted by performance.
  """
  attr(:strategies, :list, required: true)

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

  attr(:strategy, :map, required: true)
  attr(:position, :integer, required: true)

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

  attr(:strategy, :map, required: true)

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

  # ============================================================================
  # Generator Section
  # ============================================================================

  @doc """
  Renders the coupon generator section.
  """
  attr(:top_strategies, :list, required: true)
  attr(:generated_coupons, :list, default: [])

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
            <button
              phx-click="navigate"
              phx-value-section="strategies"
              class="btn btn-primary"
            >
              Wygeneruj strategię przez AI
            </button>
            <button
              phx-click="navigate"
              phx-value-section="simulations"
              class="btn btn-secondary"
            >
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

  attr(:strategies, :list, required: true)

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

  attr(:strategies, :list, required: true)

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
            <input
              type="range"
              name="coupons_count"
              min="1"
              max="10"
              value="3"
              class="range range-primary"
            />
            <div class="flex justify-between text-xs mt-2">
              <span>1</span>
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

  attr(:coupons, :list, required: true)

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
                <div class="flex gap-2 flex-wrap">
                  <%= for num <- coupon.main_numbers do %>
                    <.ball number={num} type="main" size="md" />
                  <% end %>
                </div>
              </div>
              <div>
                <p class="text-sm font-semibold mb-2">Euro liczby:</p>
                <div class="flex gap-2">
                  <%= for num <- coupon.euro_numbers do %>
                    <.ball number={num} type="euro" size="md" />
                  <% end %>
                </div>
              </div>
            </div>
          </.card>
        <% end %>
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
