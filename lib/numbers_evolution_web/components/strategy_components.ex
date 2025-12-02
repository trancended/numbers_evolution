defmodule NumbersEvolutionWeb.StrategyComponents do
  @moduledoc """
  Components for strategy management section.
  Handles strategy listing, creation via AI, and strategy cards.
  """
  use Phoenix.Component
  use Gettext, backend: NumbersEvolutionWeb.Gettext

  import NumbersEvolutionWeb.CoreComponents

  alias Phoenix.LiveView.JS

  # ============================================================================
  # Main Strategies Section
  # ============================================================================

  @doc """
  Renders the strategies management section.
  """
  attr :strategies, :list, required: true
  attr :show_strategy_form, :boolean, required: true
  attr :strategy_form_tab, :atom, required: true
  attr :generated_strategy, :map, default: nil
  attr :example_prompt, :string, default: ""

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
      <.strategy_form_modal
        show={@show_strategy_form}
        strategy_form_tab={@strategy_form_tab}
        generated_strategy={@generated_strategy}
        example_prompt={@example_prompt}
      />
    </div>
    """
  end

  # ============================================================================
  # Private Components
  # ============================================================================

  attr :show, :boolean, required: true
  attr :strategy_form_tab, :atom, required: true
  attr :generated_strategy, :map, required: true
  attr :example_prompt, :string, required: true

  defp strategy_form_modal(assigns) do
    ~H"""
    <.modal
      data-cy="strategy-form-modal"
      id="strategy-form-modal"
      show={@show}
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
        <.ai_strategy_form generated_strategy={@generated_strategy} example_prompt={@example_prompt} />
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
    """
  end

  attr :generated_strategy, :map, default: nil
  attr :example_prompt, :string, default: ""

  defp ai_strategy_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @generated_strategy do %>
        <.strategy_preview generated_strategy={@generated_strategy} />
      <% else %>
        <.strategy_prompt_form example_prompt={@example_prompt} />
      <% end %>
    </div>
    """
  end

  attr :generated_strategy, :map, required: true

  defp strategy_preview(assigns) do
    ~H"""
    <div>
      <.alert kind="success">
        <strong>✓ Strategia wygenerowana pomyślnie!</strong>
      </.alert>

      <div data-cy="strategy-preview" class="card bg-base-200 mt-4">
        <div class="card-body">
          <h3 class="card-title flex items-center gap-2">
            <.icon name="hero-sparkles" class="size-6 text-warning" />
            {@generated_strategy.strategy_name}
          </h3>
          <p class="text-sm">{@generated_strategy.description}</p>

          <div class="divider">Uzasadnienie AI</div>
          <p class="text-sm italic text-base-content/70">{@generated_strategy.reasoning}</p>

          <div class="divider">Szczegóły Reguł</div>

          <.strategy_rules_display rules={@generated_strategy.rules} />

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
    </div>
    """
  end

  attr :rules, :map, required: true

  defp strategy_rules_display(assigns) do
    ~H"""
    <div class="text-sm space-y-3">
      <div>
        <p class="font-semibold">Główne liczby (1-50):</p>
        <ul class="list-disc list-inside ml-4 space-y-1 text-base-content/70">
          <li>
            Ratio parzyste/nieparzyste: {Enum.at(@rules["main_numbers"]["ratio_even_odd"], 0)} / {Enum.at(
              @rules["main_numbers"]["ratio_even_odd"],
              1
            )}
          </li>
          <li>
            Ratio niskie/wysokie: {Enum.at(@rules["main_numbers"]["ratio_low_high"], 0)} / {Enum.at(
              @rules["main_numbers"]["ratio_low_high"],
              1
            )}
          </li>
          <li>
            Wagi: Hot {Float.round(@rules["main_numbers"]["weights"]["hot"] * 100, 0)}%,
            Cold {Float.round(Map.get(@rules["main_numbers"]["weights"], "cold", 0.0) * 100, 0)}%,
            Random {Float.round(@rules["main_numbers"]["weights"]["random"] * 100, 0)}%
          </li>
          <%= if length(@rules["main_numbers"]["blacklist"] || []) > 0 do %>
            <li>
              Blacklist: {length(@rules["main_numbers"]["blacklist"])} liczb
            </li>
          <% end %>
        </ul>
      </div>

      <div>
        <p class="font-semibold">Euro liczby (1-12):</p>
        <ul class="list-disc list-inside ml-4 space-y-1 text-base-content/70">
          <li>
            Ratio parzyste/nieparzyste: {Enum.at(@rules["euro_numbers"]["ratio_even_odd"], 0)} / {Enum.at(
              @rules["euro_numbers"]["ratio_even_odd"],
              1
            )}
          </li>
          <li>
            Wagi: Hot {Float.round(@rules["euro_numbers"]["weights"]["hot"] * 100, 0)}%,
            Random {Float.round(@rules["euro_numbers"]["weights"]["random"] * 100, 0)}%
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :example_prompt, :string, required: true

  defp strategy_prompt_form(assigns) do
    ~H"""
    <div>
      <.alert kind="info" class="text-sm">
        <strong>Opisz strategię słowami</strong> - AI wygeneruje odpowiednie reguły typowania.
      </.alert>

      <form phx-submit="create_ai_strategy" class="space-y-4 mt-4">
        <div class="form-control">
          <label class="label">
            <span class="label-text font-semibold">Opisz swoją strategię</span>
            <span class="label-text-alt">Min 10, max 1000 znaków</span>
          </label>
          <textarea
            id="strategy-prompt-textarea"
            name="prompt"
            class="textarea textarea-bordered h-32"
            placeholder="Np. Pomin połowę liczb (wszystkie parzyste), skupiamy się tylko na nieparzystych..."
            required
            minlength="10"
            maxlength="1000"
            phx-hook="SetTextareaValue"
            data-value={@example_prompt}
          >{@example_prompt}</textarea>
        </div>

        <div class="divider text-sm">Przykładowe strategie</div>

        <.strategy_templates />

        <button data-cy="generate-strategy-btn" type="submit" class="btn btn-primary w-full mt-6">
          <.icon name="hero-sparkles" class="size-5" /> Wygeneruj strategię przez AI
        </button>
      </form>
    </div>
    """
  end

  defp strategy_templates(assigns) do
    templates = [
      %{
        id: "tylko_nieparzyste",
        name: "Tylko Nieparzyste",
        desc: "Pomija wszystkie parzyste",
        class: "btn-outline"
      },
      %{
        id: "dwie_nieparzyste_trzy_parzyste",
        name: "2 Nieparzyste, 3 Parzyste",
        desc: "Precyzyjne ratio",
        class: "btn-outline"
      },
      %{
        id: "max_dwie_w_dziesiatce",
        name: "Max 2 w Dziesiątce",
        desc: "Rozproszone liczby",
        class: "btn-outline"
      },
      %{
        id: "balans_hot_cold",
        name: "Balans Hot/Cold",
        desc: "Zrównoważona strategia",
        class: "btn-outline"
      },
      %{
        id: "ekstremalna_hot",
        name: "Ekstremalna Hot",
        desc: "80% gorących liczb",
        class: "btn-outline"
      },
      %{
        id: "przeciwny_trend",
        name: "Przeciwny Trend",
        desc: "Gra na cold numbers",
        class: "btn-outline"
      },
      %{
        id: "vip1",
        name: "🎰 VIP1",
        desc: "50% liczb (AI blacklist), max 2/dziesiątkę",
        class: "btn-warning"
      },
      %{
        id: "vip2",
        name: "🎲 VIP2",
        desc: "50% liczb (auto przy każdej symulacji)",
        class: "btn-secondary"
      }
    ]

    assigns = assign(assigns, :templates, templates)

    ~H"""
    <div class="grid md:grid-cols-2 gap-2">
      <%= for template <- @templates do %>
        <button
          data-cy={"template-#{template.id}"}
          type="button"
          phx-click="use_strategy_template"
          phx-value-strategy={template.id}
          class={["btn btn-sm justify-start text-left min-h-[4rem] py-3", template.class]}
        >
          <div class="flex flex-col items-start gap-1">
            <div class="font-semibold text-left w-full">{template.name}</div>
            <div class="text-xs opacity-70 text-left w-full">{template.desc}</div>
          </div>
        </button>
      <% end %>
    </div>
    """
  end

  attr :strategy, :map, required: true

  defp strategy_card(assigns) do
    ~H"""
    <.card class="flex flex-col h-full">
      <div class="flex items-center gap-2 mb-2">
        <h3 class="font-bold text-lg">{@strategy.name}</h3>
        <.badge variant={if @strategy.type == :ai_generated, do: "success", else: "info"} size="sm">
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
end
