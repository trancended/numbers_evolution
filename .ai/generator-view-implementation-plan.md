# Plan implementacji widoku Generator

## 1. Przegląd

Sekcja Generator umożliwia użytkownikom generowanie konkretnych propozycji liczb do zagrania na podstawie ich top strategii. Jest to ostatni krok w workflow aplikacji: tworzenie strategii → testowanie w symulacjach → wybór najlepszych → generowanie kuponów do zagrania. Generator wykorzystuje sprawdzone strategie do utworzenia od 1 do 10 kuponów, które użytkownik może wykorzystać w prawdziwym losowaniu.

## 2. Routing widoku

Widok dostępny na głównej ścieżce `/` z parametrem `@active_section = :generator`.

**Routing**:
- URL: `/`
- LiveView: `NumbersEvolutionWeb.PageLive`
- Komponent: `generator_section/1` z `NumbersEvolutionWeb.SectionsComponents`
- Dostęp: Wymagana autentykacja

## 3. Struktura komponentów

```
PageLive (LiveView - kontener główny)
└── generator_section (function component)
    ├── Nagłówek
    ├── Empty state (gdy brak top strategii)
    │   └── CTA buttons (Wygeneruj strategię, Uruchom symulację)
    ├── Top 3 Strategie (karta informacyjna)
    │   └── top_strategies_display (subkomponent)
    │       └── Mini-karty top 3 strategii
    ├── Formularz generowania
    │   └── generator_form (subkomponent)
    │       ├── Select strategii
    │       ├── Range slider dla liczby kuponów (1-10)
    │       └── Przycisk "Generuj propozycje"
    └── Wygenerowane kupony (warunkowy)
        └── generated_coupons_display (subkomponent)
            └── Karty kuponów × n
                ├── Główne liczby (balls × 5)
                └── Euro liczby (balls × 2)
```

## 4. Szczegóły komponentów

### Generator Section (generator_section/1)

**Opis komponentu**: Główny kontener sekcji generatora, który wyświetla top strategie, formularz generowania i wygenerowane kupony.

**Główne elementy HTML i komponenty dzieci**:
- Nagłówek `<h1>`
- Warunkowy empty state
- Karta z top 3 strategiami (`<.top_strategies_display>`)
- Karta z formularzem (`<.generator_form>`)
- Sekcja wygenerowanych kuponów (`<.generated_coupons_display>`) - warunkowa

**Obsługiwane zdarzenia**:
- `phx-click="generate_coupons"` - generowanie kuponów
- `phx-click="regenerate_coupons"` - ponowne generowanie (nowe losowe liczby)
- `phx-click="navigate"` - nawigacja (w empty state)

**Warunki walidacji**:
- Empty state renderowany gdy `@top_strategies == []`
- Formularz renderowany gdy `@top_strategies != []`
- Sekcja kuponów renderowana gdy `@generated_coupons != []`

**Typy**:
```elixir
attr :top_strategies, :list, required: true      # list(Strategy.t()) - max 3
attr :generated_coupons, :list, default: []      # list(coupon_map())
```

**Propsy**: Jak w typach powyżej

### Top Strategies Display (top_strategies_display/1)

**Opis komponentu**: Wyświetla 3 najlepsze strategie użytkownika jako kontekst dla generowania kuponów.

**Główne elementy HTML**:
- Karta DaisyUI (`<.card class="bg-base-200">`)
- Grid z 3 mini-kartami (każda strategia)
- Pozycja (#1, #2, #3), nazwa i score

**Obsługiwane zdarzenia**: Brak (czysto prezentacyjny)

**Warunki walidacji**: Brak

**Typy**:
```elixir
attr :strategies, :list, required: true  # max 3 elementy
```

**Propsy**: Jak w typach powyżej

### Generator Form (generator_form/1)

**Opis komponentu**: Formularz do wyboru strategii i liczby kuponów do wygenerowania.

**Główne elementy HTML**:
- Select dla strategii (`<select name="strategy_id">`)
- Range slider dla liczby kuponów (`<input type="range" min="1" max="10">`)
- Wizualne wskaźniki wartości slidera (1, 5, 10)
- Przycisk "Generuj propozycje"

**Obsługiwane zdarzenia**:
- `phx-click="generate_coupons"` (lub `phx-submit` jeśli form)
- Opcjonalnie: live update slidera przez JS

**Warunki walidacji**:
- `strategy_id`: wymagane
- `coupons_count`: 1-10 (HTML5 range constraint)

**Typy**:
```elixir
attr :strategies, :list, required: true
```

**Propsy**: Jak w typach powyżej

### Generated Coupons Display (generated_coupons_display/1)

**Opis komponentu**: Wyświetla wygenerowane kupony w formie kart z wizualizacją numerów przez komponenty ball.

**Główne elementy HTML**:
- Nagłówek + przycisk "Wylosuj inne"
- Grid kart kuponów (`<div class="grid md:grid-cols-2 gap-4">`)
- Każda karta:
  - Tytuł "Kupon N"
  - Sekcja głównych liczb (balls × 5)
  - Sekcja euro liczb (balls × 2)

**Obsługiwane zdarzenia**:
- `phx-click="regenerate_coupons"` - regeneracja z tymi samymi parametrami

**Warunki walidacji**: Renderowany tylko gdy `@coupons != []`

**Typy**:
```elixir
attr :coupons, :list, required: true  # list(coupon_map())
```

**Propsy**: Jak w typach powyżej

## 5. Typy

### Coupon (ViewModel)

```elixir
# Struktura pojedynczego kuponu
%{
  main_numbers: [1, 7, 23, 34, 50],  # lista 5 liczb (1-50), posortowana
  euro_numbers: [3, 9]                # lista 2 liczb (1-12), posortowana
}
```

### Generated Coupons Response

```elixir
# Struktura odpowiedzi z funkcji generowania
{:ok, [
  %{main_numbers: [1, 7, 23, 34, 50], euro_numbers: [3, 9]},
  %{main_numbers: [2, 12, 25, 38, 47], euro_numbers: [1, 11]},
  # ... więcej kuponów
]}
```

### Strategy (top strategies)

```elixir
# Strategie z performance_score (tylko top 3)
%Strategy{
  id: "uuid",
  name: "Hot Numbers Focus",
  performance_score: 85430.5,
  rules: %{...},
  ...
}
```

## 6. Zarządzanie stanem

**Architektura stanu**: Centralne zarządzanie w `PageLive`, komponenty bezstanowe.

**Stan zarządzany w PageLive**:
```elixir
socket
|> assign(:top_strategies, [])           # top 3 strategie
|> assign(:generated_coupons, [])        # wygenerowane kupony
|> assign(:selected_strategy_id, nil)    # ID wybranej strategii (opcjonalnie)
|> assign(:coupons_count, 3)             # liczba kuponów do wygenerowania (opcjonalnie)
```

**Ładowanie danych**:
```elixir
defp load_generator_data(socket) do
  user = socket.assigns.current_user
  
  # Pobierz top 3 strategie według performance score
  top_strategies =
    if user,
      do:
        Strategies.list_strategies(user, sort: "performance_score", order: "asc")
        |> Enum.take(3),
      else: []
  
  assign(socket, :top_strategies, top_strategies)
end
```

**Event handler generowania kuponów**:
```elixir
def handle_event("generate_coupons", params, socket) do
  %{"strategy_id" => strategy_id, "coupons_count" => count_str} = params
  coupons_count = String.to_integer(count_str)
  
  # Pobierz strategię
  strategy = Enum.find(socket.assigns.top_strategies, &(&1.id == strategy_id))
  
  if strategy do
    # Wygeneruj kupony
    coupons = Generator.generate_coupons(strategy.rules, coupons_count)
    
    {:noreply,
     socket
     |> assign(:generated_coupons, coupons)
     |> assign(:selected_strategy_id, strategy_id)
     |> assign(:coupons_count, coupons_count)}
  else
    {:noreply, put_flash(socket, :error, "Strategia nie znaleziona")}
  end
end

def handle_event("regenerate_coupons", _params, socket) do
  # Użyj zapisanych parametrów
  strategy_id = socket.assigns.selected_strategy_id
  coupons_count = socket.assigns.coupons_count || 3
  
  strategy = Enum.find(socket.assigns.top_strategies, &(&1.id == strategy_id))
  
  if strategy do
    coupons = Generator.generate_coupons(strategy.rules, coupons_count)
    
    {:noreply, assign(socket, :generated_coupons, coupons)}
  else
    {:noreply, socket}
  end
end
```

**Custom hooki**: Nie wymagane

## 7. Integracja API

### Strategies.list_strategies/2 (top 3)

**Request**:
```elixir
Strategies.list_strategies(user, sort: "performance_score", order: "asc")
|> Enum.take(3)
```

**Response**:
```elixir
[
  %Strategy{id: "uuid", name: "Best", performance_score: 85430.5, rules: %{...}},
  %Strategy{id: "uuid", name: "Second", performance_score: 92150.0, rules: %{...}},
  %Strategy{id: "uuid", name: "Third", performance_score: 105200.5, rules: %{...}}
]
```

### Generator.generate_coupons/2

**Request**:
```elixir
Generator.generate_coupons(rules, count)
# rules: strategy.rules (%{})
# count: 1..10
```

**Response**:
```elixir
[
  %{main_numbers: [1, 7, 23, 34, 50], euro_numbers: [3, 9]},
  %{main_numbers: [5, 12, 28, 39, 47], euro_numbers: [2, 11]},
  # ... count kuponów
]
```

**Implementacja**:
```elixir
defmodule NumbersEvolution.Generator do
  alias NumbersEvolution.NumberGenerator
  
  @doc """
  Generuje N kuponów na podstawie reguł strategii.
  
  Każdy kupon to niezależna generacja liczb według strategii.
  """
  def generate_coupons(rules, count) when count >= 1 and count <= 10 do
    1..count
    |> Enum.map(fn _ ->
      NumberGenerator.generate_numbers(rules)
    end)
    |> Enum.map(fn %{main: main, euro: euro} ->
      %{
        main_numbers: Enum.sort(main),
        euro_numbers: Enum.sort(euro)
      }
    end)
  end
  
  def generate_coupons(_rules, _count), do: {:error, :invalid_count}
end
```

**Algorytm generowania** (z NumberGenerator):
- Użycie reguł strategii (ratio, wagi, preferowane liczby)
- Generowanie niezależnych zestawów dla każdego kuponu
- Sortowanie liczb przed zwróceniem

## 8. Interakcje użytkownika

### Generowanie kuponów

**Krok 1**: Wybór strategii
- User klika select i wybiera jedną z top 3 strategii
- Domyślnie: pierwsza strategia (najlepsza)

**Krok 2**: Wybór liczby kuponów
- User przesuwa slider od 1 do 10
- Wartość wyświetlana wizualnie
- Domyślnie: 3 kupony

**Krok 3**: Kliknięcie "Generuj propozycje"
- Event: `phx-click="generate_coupons"` z danymi formularza
- Handler wywołuje: `Generator.generate_coupons(rules, count)`
- Rezultat: Wyświetlenie sekcji z kuponami

**Krok 4**: Przejrzenie kuponów
- User scrolluje przez wygenerowane kupony
- Każdy kupon wyświetla liczby jako kolorowe kółka (balls)

### Regenerowanie kuponów

**Trigger**: Kliknięcie "Wylosuj inne"
- Event: `phx-click="regenerate_coupons"`
- Handler używa zapisanych parametrów (strategia, liczba)
- Rezultat: Nowe kupony z tymi samymi ustawieniami

### Nawigacja z empty state

**Trigger**: Kliknięcie "Wygeneruj strategię przez AI" lub "Uruchom symulację"
- Event: `phx-click="navigate"` z `phx-value-section`
- Rezultat: Przejście do odpowiedniej sekcji

### Opcjonalne: Export kuponów (TODO - przyszłość)

**Trigger**: Kliknięcie "Eksportuj" lub "Drukuj"
- Generowanie PDF z kuponami
- Lub kopiowanie do schowka

## 9. Warunki i walidacja

### Warunek renderowania empty state

**Sprawdzany w**: `generator_section/1`

**Warunek**: `@top_strategies == []`

**Wpływ na UI**:
- Empty state z komunikatem
- Przyciski CTA do strategii i symulacji
- Brak formularza generowania

**Przyczyny braku top strategies**:
- User nie ma żadnych strategii
- User ma strategie, ale bez performance_score (brak symulacji)

### Warunek wyświetlania top strategies display

**Sprawdzany w**: `generator_section/1`

**Warunek**: `@top_strategies != []`

**Wpływ na UI**: Wyświetlenie karty z top 3 strategiami

### Warunek wyświetlania wygenerowanych kuponów

**Sprawdzany w**: `generator_section/1`

**Warunek**: `@generated_coupons != []`

**Wpływ na UI**:
- Jeśli puste: brak sekcji kuponów
- Jeśli nie puste: wyświetlenie karty z kuponami

### Walidacja liczby kuponów

**Sprawdzane w**: Formularz (HTML5) + backend

**Frontend** (HTML5):
```heex
<input type="range" min="1" max="10" value="3" name="coupons_count">
```

**Backend**:
```elixir
def generate_coupons(rules, count) when count >= 1 and count <= 10 do
  # OK
end

def generate_coupons(_rules, _count) do
  {:error, :invalid_count}
end
```

**Wpływ na UI**: 
- Slider ogranicza wartości do 1-10
- Backend dodatkowo waliduje

### Warunek dostępności przycisku "Wylosuj inne"

**Sprawdzany w**: `generated_coupons_display/1`

**Warunek**: Przycisk zawsze aktywny gdy są kupony

**Wpływ**: User może regenerować kupony dowolną liczbę razy

## 10. Obsługa błędów

### Błąd - brak top strategii

**Scenariusz**: Nowy użytkownik lub brak symulacji

**Obsługa**: Empty state
```heex
<.empty_state icon="hero-sparkles">
  <:title>Brak top strategii</:title>
  <:description>Najpierw uruchom symulacje aby znaleźć najlepsze strategie</:description>
  <:action>
    <button phx-click="navigate" phx-value-section="strategies" class="btn btn-primary">
      Wygeneruj strategię przez AI
    </button>
    <button phx-click="navigate" phx-value-section="simulations" class="btn btn-secondary">
      Uruchom symulację
    </button>
  </:action>
</.empty_state>
```

**UI**: Przyjazny komunikat z akcjami

### Błąd - strategia nie znaleziona

**Scenariusz**: Manipulacja ID strategii w request

**Obsługa**:
```elixir
strategy = Enum.find(socket.assigns.top_strategies, &(&1.id == strategy_id))

if strategy do
  # OK
else
  {:noreply, put_flash(socket, :error, "Strategia nie znaleziona")}
end
```

**UI**: Flash error, kupony nie są generowane

### Błąd - nieprawidłowa liczba kuponów

**Scenariusz**: Manipulacja parametru `coupons_count`

**Obsługa** (backend):
```elixir
def generate_coupons(_rules, count) when count < 1 or count > 10 do
  {:error, :invalid_count}
end
```

**UI**: Flash error: "Liczba kuponów musi być między 1 a 10"

### Błąd - generowanie liczb (crash NumberGenerator)

**Scenariusz**: Błąd w logice generowania (nieprawidłowe reguły)

**Obsługa** (try/rescue):
```elixir
def handle_event("generate_coupons", params, socket) do
  try do
    coupons = Generator.generate_coupons(strategy.rules, coupons_count)
    
    {:noreply, assign(socket, :generated_coupons, coupons)}
  rescue
    e ->
      Logger.error("Failed to generate coupons: #{inspect(e)}")
      
      {:noreply, put_flash(socket, :error, "Nie udało się wygenerować kuponów. Spróbuj ponownie.")}
  end
end
```

**UI**: Flash error z komunikatem, formularz pozostaje dostępny

## 11. Kroki implementacji

### Krok 1: Przygotowanie struktury

1.1. W `lib/numbers_evolution_web/components/sections_components.ex` dodać:
```elixir
attr :top_strategies, :list, required: true
attr :generated_coupons, :list, default: []

def generator_section(assigns) do
  ~H"""
  <div class="space-y-8">
    <h1 class="text-4xl font-bold">Generator Propozycji</h1>
    
    <%!-- Reszta w kolejnych krokach --%>
  </div>
  """
end
```

### Krok 2: Implementacja empty state

2.1. Dodać warunkowy empty state:
```heex
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
<% end %>
```

### Krok 3: Implementacja top_strategies_display

3.1. Dodać subkomponent:
```elixir
attr :strategies, :list, required: true

defp top_strategies_display(assigns) do
  ~H"""
  <div class="card bg-base-200">
    <div class="card-body">
      <h2 class="card-title">Top 3 Strategie</h2>
      <div class="grid md:grid-cols-3 gap-4 mt-4">
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
```

3.2. Dodać w głównym template:
```heex
<% else %>
  <.top_strategies_display strategies={@top_strategies} />
```

### Krok 4: Implementacja generator_form

4.1. Dodać subkomponent:
```elixir
attr :strategies, :list, required: true

defp generator_form(assigns) do
  ~H"""
  <div class="card bg-base-100 shadow-xl">
    <div class="card-body">
      <h2 class="card-title">Generuj propozycje</h2>
      
      <div class="form-control">
        <label class="label">
          <span class="label-text">Wybierz strategię</span>
        </label>
        <select id="strategy-select" class="select select-bordered">
          <%= for strategy <- @strategies do %>
            <option value={strategy.id}>{strategy.name}</option>
          <% end %>
        </select>
      </div>
      
      <div class="form-control">
        <label class="label">
          <span class="label-text">Liczba kuponów (1-10)</span>
        </label>
        <input
          id="coupons-count-range"
          type="range"
          min="1"
          max="10"
          value="3"
          class="range range-primary"
        />
        <div class="flex justify-between text-xs mt-2">
          <span>1</span>
          <span>5</span>
          <span>10</span>
        </div>
      </div>
      
      <button
        phx-click="generate_coupons"
        phx-value-strategy_id={JS.get_attribute("#strategy-select", "value")}
        phx-value-coupons_count={JS.get_attribute("#coupons-count-range", "value")}
        class="btn btn-primary mt-4"
      >
        <.icon name="hero-sparkles" class="size-5" /> Generuj propozycje
      </button>
    </div>
  </div>
  """
end
```

**Uwaga**: Użycie JS helpers może wymagać dostosowania. Alternatywnie użyć standardowego form z `phx-submit`:

```heex
<form phx-submit="generate_coupons" class="space-y-4">
  <div class="form-control">
    <label class="label">
      <span class="label-text">Wybierz strategię</span>
    </label>
    <select name="strategy_id" class="select select-bordered" required>
      <%= for strategy <- @strategies do %>
        <option value={strategy.id}>{strategy.name}</option>
      <% end %>
    </select>
  </div>
  
  <div class="form-control">
    <label class="label">
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
      <span>5</span>
      <span>10</span>
    </div>
  </div>
  
  <button type="submit" class="btn btn-primary w-full mt-4">
    <.icon name="hero-sparkles" class="size-5" /> Generuj propozycje
  </button>
</form>
```

4.2. Dodać w głównym template:
```heex
<.generator_form strategies={@top_strategies} />
```

### Krok 5: Implementacja generated_coupons_display

5.1. Dodać subkomponent:
```elixir
attr :coupons, :list, required: true

defp generated_coupons_display(assigns) do
  ~H"""
  <div class="space-y-4">
    <div class="flex justify-between items-center">
      <h2 class="text-2xl font-bold">Wygenerowane kupony</h2>
      <button phx-click="regenerate_coupons" class="btn btn-secondary">
        <.icon name="hero-arrow-path" class="size-5" /> Wylosuj inne
      </button>
    </div>
    
    <div class="grid md:grid-cols-2 gap-4">
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
```

5.2. Dodać w głównym template (po formularzu):
```heex
<%= if @generated_coupons != [] do %>
  <.generated_coupons_display coupons={@generated_coupons} />
<% end %>
```

### Krok 6: Event handlers w PageLive

6.1. Dodać handler generowania:
```elixir
def handle_event("generate_coupons", params, socket) do
  %{"strategy_id" => strategy_id, "coupons_count" => count_str} = params
  
  # Parsuj liczbę kuponów
  coupons_count = case Integer.parse(count_str) do
    {num, _} when num >= 1 and num <= 10 -> num
    _ -> 3  # default
  end
  
  # Znajdź strategię
  strategy = Enum.find(socket.assigns.top_strategies, &(&1.id == strategy_id))
  
  if strategy do
    # Wygeneruj kupony
    coupons = NumbersEvolution.Generator.generate_coupons(strategy.rules, coupons_count)
    
    {:noreply,
     socket
     |> assign(:generated_coupons, coupons)
     |> assign(:selected_strategy_id, strategy_id)
     |> assign(:coupons_count, coupons_count)}
  else
    {:noreply, put_flash(socket, :error, "Strategia nie znaleziona")}
  end
rescue
  e ->
    Logger.error("Failed to generate coupons: #{inspect(e)}")
    {:noreply, put_flash(socket, :error, "Nie udało się wygenerować kuponów")}
end

def handle_event("regenerate_coupons", _params, socket) do
  strategy_id = socket.assigns[:selected_strategy_id]
  coupons_count = socket.assigns[:coupons_count] || 3
  
  strategy = Enum.find(socket.assigns.top_strategies, &(&1.id == strategy_id))
  
  if strategy do
    coupons = NumbersEvolution.Generator.generate_coupons(strategy.rules, coupons_count)
    {:noreply, assign(socket, :generated_coupons, coupons)}
  else
    {:noreply, socket}
  end
rescue
  e ->
    Logger.error("Failed to regenerate coupons: #{inspect(e)}")
    {:noreply, put_flash(socket, :error, "Nie udało się wygenerować kuponów")}
end
```

6.2. Inicjalizacja assigns w `initialize_section_data/2`:
```elixir
defp initialize_section_data(socket, _user) do
  socket
  # ... reszta
  |> assign(:generated_coupons, [])
  |> assign(:selected_strategy_id, nil)
  |> assign(:coupons_count, 3)
end
```

### Krok 7: Backend - Generator module

7.1. Utworzyć `lib/numbers_evolution/generator.ex`:
```elixir
defmodule NumbersEvolution.Generator do
  @moduledoc """
  Generuje propozycje kuponów na podstawie strategii.
  """
  
  alias NumbersEvolution.NumberGenerator
  
  @doc """
  Generuje N kuponów na podstawie reguł strategii.
  
  Każdy kupon to niezależna generacja liczb według strategii.
  
  ## Examples
  
      iex> Generator.generate_coupons(strategy.rules, 3)
      [
        %{main_numbers: [1, 7, 23, 34, 50], euro_numbers: [3, 9]},
        %{main_numbers: [5, 12, 28, 39, 47], euro_numbers: [2, 11]},
        %{main_numbers: [3, 15, 22, 41, 49], euro_numbers: [1, 8]}
      ]
  """
  def generate_coupons(rules, count) when is_integer(count) and count >= 1 and count <= 10 do
    1..count
    |> Enum.map(fn _ ->
      # Wygeneruj liczby
      %{main: main, euro: euro} = NumberGenerator.generate_numbers(rules)
      
      # Zwróć w formacie kuponu
      %{
        main_numbers: Enum.sort(main),
        euro_numbers: Enum.sort(euro)
      }
    end)
  end
  
  def generate_coupons(_rules, _count), do: {:error, :invalid_count}
end
```

### Krok 8: Testowanie

8.1. Testy jednostkowe Generator:
```elixir
# test/numbers_evolution/generator_test.exs
defmodule NumbersEvolution.GeneratorTest do
  use NumbersEvolution.DataCase
  
  alias NumbersEvolution.Generator
  
  describe "generate_coupons/2" do
    test "generates correct number of coupons" do
      rules = valid_rules()
      
      coupons = Generator.generate_coupons(rules, 5)
      
      assert length(coupons) == 5
    end
    
    test "each coupon has 5 main numbers and 2 euro numbers" do
      rules = valid_rules()
      
      coupons = Generator.generate_coupons(rules, 3)
      
      for coupon <- coupons do
        assert length(coupon.main_numbers) == 5
        assert length(coupon.euro_numbers) == 2
      end
    end
    
    test "main numbers are in range 1-50" do
      rules = valid_rules()
      
      coupons = Generator.generate_coupons(rules, 3)
      
      for coupon <- coupons do
        assert Enum.all?(coupon.main_numbers, &(&1 >= 1 and &1 <= 50))
      end
    end
    
    test "euro numbers are in range 1-12" do
      rules = valid_rules()
      
      coupons = Generator.generate_coupons(rules, 3)
      
      for coupon <- coupons do
        assert Enum.all?(coupon.euro_numbers, &(&1 >= 1 and &1 <= 12))
      end
    end
    
    test "numbers are sorted" do
      rules = valid_rules()
      
      coupons = Generator.generate_coupons(rules, 3)
      
      for coupon <- coupons do
        assert coupon.main_numbers == Enum.sort(coupon.main_numbers)
        assert coupon.euro_numbers == Enum.sort(coupon.euro_numbers)
      end
    end
    
    test "returns error for invalid count" do
      rules = valid_rules()
      
      assert {:error, :invalid_count} = Generator.generate_coupons(rules, 0)
      assert {:error, :invalid_count} = Generator.generate_coupons(rules, 11)
      assert {:error, :invalid_count} = Generator.generate_coupons(rules, -1)
    end
  end
  
  defp valid_rules do
    %{
      "main_numbers" => %{
        "ratio_even_odd" => [2, 3],
        "ratio_low_high" => [3, 2],
        "weights" => %{"hot" => 0.5, "cold" => 0.2, "random" => 0.3}
      },
      "euro_numbers" => %{
        "ratio_even_odd" => [1, 1],
        "weights" => %{"hot" => 0.6, "random" => 0.4}
      }
    }
  end
end
```

8.2. Testy LiveView:
```elixir
test "displays top 3 strategies", %{conn: conn} do
  user = insert(:user)
  strategy1 = insert(:strategy, user: user, name: "Best", performance_score: 100.0)
  strategy2 = insert(:strategy, user: user, name: "Second", performance_score: 200.0)
  strategy3 = insert(:strategy, user: user, name: "Third", performance_score: 300.0)
  
  conn = log_in_user(conn, user)
  {:ok, view, _html} = live(conn, "/")
  
  view |> element("button", "Generator") |> render_click()
  
  assert render(view) =~ "Best"
  assert render(view) =~ "Second"
  assert render(view) =~ "Third"
end

test "generates coupons when form submitted", %{conn: conn} do
  user = insert(:user)
  strategy = insert(:strategy, user: user, performance_score: 100.0)
  
  conn = log_in_user(conn, user)
  {:ok, view, _html} = live(conn, "/")
  
  view |> element("button", "Generator") |> render_click()
  
  view
  |> form("form", %{"strategy_id" => strategy.id, "coupons_count" => "3"})
  |> render_submit()
  
  html = render(view)
  
  assert html =~ "Wygenerowane kupony"
  assert html =~ "Kupon 1"
  assert html =~ "Kupon 2"
  assert html =~ "Kupon 3"
end

test "regenerates coupons with same parameters", %{conn: conn} do
  user = insert(:user)
  strategy = insert(:strategy, user: user, performance_score: 100.0)
  
  conn = log_in_user(conn, user)
  {:ok, view, _html} = live(conn, "/")
  
  view |> element("button", "Generator") |> render_click()
  
  # Wygeneruj pierwsze kupony
  view
  |> form("form", %{"strategy_id" => strategy.id, "coupons_count" => "2"})
  |> render_submit()
  
  html_before = render(view)
  
  # Regeneruj
  view |> element("button", "Wylosuj inne") |> render_click()
  
  html_after = render(view)
  
  # Liczba kuponów powinna się zachować
  assert html_after =~ "Kupon 1"
  assert html_after =~ "Kupon 2"
  refute html_after =~ "Kupon 3"
  
  # Liczby mogą być inne (losowe)
end

test "shows empty state when no top strategies", %{conn: conn} do
  user = insert(:user)
  # Brak strategii z performance_score
  
  conn = log_in_user(conn, user)
  {:ok, view, _html} = live(conn, "/")
  
  view |> element("button", "Generator") |> render_click()
  
  assert render(view) =~ "Brak top strategii"
  assert has_element?(view, "button", "Wygeneruj strategię przez AI")
end
```

### Krok 9: Styling i UX

9.1. Dodać animacje dla balls (opcjonalnie):
```css
/* app.css */
.ball {
  @apply transition-transform duration-200;
}

.ball:hover {
  @apply scale-110;
}
```

9.2. Responsive grid dla kuponów:
- Mobile: 1 kolumna
- Tablet+: 2 kolumny

9.3. Dodać tooltips (opcjonalnie):
- Dla top strategies: Pokaż szczegóły strategii
- Dla balls: Pokaż kategorię (hot/cold/random)

### Krok 10: Opcjonalne ulepszenia

10.1. Dodać przycisk "Kopiuj do schowka":
```heex
<button
  phx-click={JS.dispatch("phx:copy", to: "#coupon-#{index}")}
  class="btn btn-sm btn-ghost"
>
  <.icon name="hero-clipboard" /> Kopiuj
</button>
```

10.2. Dodać eksport do PDF (zaawansowane):
```elixir
def handle_event("export_pdf", _params, socket) do
  coupons = socket.assigns.generated_coupons
  
  pdf_binary = PDFGenerator.generate_coupons_pdf(coupons)
  
  {:noreply,
   socket
   |> push_event("download", %{
     filename: "coupons_#{Date.utc_today()}.pdf",
     content: Base.encode64(pdf_binary)
   })}
end
```

10.3. Dodać historię wygenerowanych kuponów (zaawansowane):
- Zapisywanie w bazie danych
- Przeglądanie historii
- Możliwość powtórzenia generacji

---

**Status implementacji**: ✅ Podstawowa struktura zaimplementowana
**Priorytet dla MVP**: ŚREDNI (finalna funkcjonalność, zależna od reszty)
**Zależności**: Wymaga `Strategies`, `NumberGenerator`
**Następne kroki**: Testowanie, opcjonalne funkcje (export, historia)

