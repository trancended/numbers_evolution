# Plan implementacji widoku Ranking

## 1. Przegląd

Sekcja Ranking wyświetla ranking strategii użytkownika posortowany według skuteczności (performance score - mediana liczby prób ze wszystkich symulacji). Jest to widok read-only, który pozwala użytkownikowi szybko zidentyfikować najlepsze strategie i porównać ich efektywność. Ranking wizualnie wyróżnia top 3 strategie i oddziela strategie bez danych (bez przeprowadzonych symulacji).

## 2. Routing widoku

Widok dostępny na głównej ścieżce `/` z parametrem `@active_section = :ranking`.

**Routing**:
- URL: `/`
- LiveView: `NumbersEvolutionWeb.PageLive`
- Komponent: `ranking_section/1` z `NumbersEvolutionWeb.SectionsComponents`
- Dostęp: Wymagana autentykacja

## 3. Struktura komponentów

```
PageLive (LiveView - kontener główny)
└── ranking_section (function component)
    ├── Nagłówek
    ├── Empty state (gdy brak strategii z performance score)
    │   └── CTA "Uruchom symulację"
    └── Lista rankingowa
        ├── ranking_card × n (strategie z performance score)
        │   ├── Pozycja w rankingu (#1, #2, #3...)
        │   ├── Ikona trofeum (dla top 3)
        │   ├── Nazwa i badge typu
        │   └── Stats box z performance score
        └── Divider + unranked_strategy_card × m (strategie bez danych)
            └── Przycisk "Uruchom symulację"
```

## 4. Szczegóły komponentów

### Ranking Section (ranking_section/1)

**Opis komponentu**: Główny kontener sekcji rankingu, który sortuje strategie według performance score i deleguje renderowanie do subkomponentów.

**Główne elementy HTML i komponenty dzieci**:
- Nagłówek `<h1>`
- Warunkowy empty state
- Lista kart rankingowych (`<div class="space-y-4">`)
- Divider ("Strategie bez symulacji")
- Lista kart nierangowanych

**Obsługiwane zdarzenia**:
- `phx-click="navigate"` z `phx-value-section` - nawigacja (w subkomponentach)
- Brak lokalnych event handlers

**Warunki walidacji**:
- Empty state renderowany gdy `ranked_strategies == []` (wszystkie strategie bez performance_score)
- Divider i unranked cards renderowane gdy `unranked_strategies != []`

**Typy**:
```elixir
attr :strategies, :list, required: true  # list(Strategy.t())
```

**Propsy**: Jak w typach powyżej

**Logika przygotowania danych** (w komponencie):
```elixir
def ranking_section(assigns) do
  ranked_strategies =
    assigns.strategies
    |> Enum.reject(&is_nil(&1.performance_score))
    |> Enum.sort_by(& &1.performance_score, :asc)  # niższy score = lepszy
  
  unranked_strategies =
    assigns.strategies
    |> Enum.filter(&is_nil(&1.performance_score))
  
  assigns =
    assigns
    |> assign(:ranked_strategies, ranked_strategies)
    |> assign(:unranked_strategies, unranked_strategies)
  
  # Template
end
```

### Ranking Card (ranking_card/1)

**Opis komponentu**: Karta pojedynczej strategii w rankingu z pozycją, ikoną (dla top 3), nazwą i performance score. Top 3 strategie mają specjalne wyróżnienie wizualne.

**Główne elementy HTML**:
- `<.card>` z warunkowym ring/border (top 3)
- Pozycja w rankingu (duża liczba)
- Ikona trofeum (tylko dla top 3)
- Nazwa strategii + badge typu
- Stats box z performance score

**Obsługiwane zdarzenia**: Brak (komponent czysto prezentacyjny)

**Warunki walidacji**: Brak

**Typy**:
```elixir
attr :strategy, :map, required: true      # Strategy.t()
attr :position, :integer, required: true  # 1-based position
```

**Propsy**: Jak w typach powyżej

**Kolory dla top 3**:
- Pozycja #1: `text-warning` (złoty/żółty)
- Pozycja #2: `text-base-300` (srebrny/szary)
- Pozycja #3: `text-amber-700` (brązowy)

### Unranked Strategy Card (unranked_strategy_card/1)

**Opis komponentu**: Karta strategii bez performance score (nie przeprowadzono jeszcze żadnej symulacji). Zawiera link do uruchomienia symulacji.

**Główne elementy HTML**:
- `<.card class="opacity-60">` - przyciemniona
- Placeholder pozycji ("—")
- Nazwa strategii + badge "Brak danych"
- Przycisk "Uruchom symulację"

**Obsługiwane zdarzenia**:
- `phx-click="navigate"` z `phx-value-section="simulations"` - nawigacja do symulacji

**Warunki walidacji**: Brak

**Typy**:
```elixir
attr :strategy, :map, required: true  # Strategy.t()
```

**Propsy**: Jak w typach powyżej

## 5. Typy

### Strategy (z performance score)

```elixir
defmodule NumbersEvolution.Strategies.Strategy do
  # ... (schema jak w strategies-view-implementation-plan.md)
  
  # Pola istotne dla rankingu:
  field :name, :string
  field :type, Ecto.Enum, values: [:manual, :ai_generated]
  field :performance_score, :float  # mediana liczby prób (może być nil)
  field :description, :string
end
```

### PerformanceScoreCalculation

Performance score to mediana liczby prób (`attempts_count`) ze wszystkich udanych symulacji dla danej strategii.

**Wzór (PostgreSQL)**:
```sql
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY attempts_count)
FROM simulations
WHERE strategy_id = ? AND status = 'success'
```

**Dlaczego mediana, a nie średnia?**
- Mniej wrażliwa na outliers (bardzo niskie lub bardzo wysokie wartości)
- Lepiej reprezentuje "typową" wydajność strategii
- Zgodnie z PRD (6.4.2 Ranking strategii)

## 6. Zarządzanie stanem

**Architektura stanu**: Centralne zarządzanie w `PageLive`, komponenty bezstanowe.

**Stan zarządzany w PageLive**:
```elixir
socket
|> assign(:strategies, [])  # lista strategii użytkownika
```

**Ładowanie danych**:
```elixir
defp load_ranking(socket) do
  user = socket.assigns.current_user
  
  # Pobierz strategie posortowane według performance_score
  strategies =
    if user,
      do: Strategies.list_strategies(user, sort: "performance_score", order: "asc"),
      else: []
  
  assign(socket, :strategies, strategies)
end
```

**Custom hooki**: Nie wymagane (widok read-only)

**Aktualizacja danych**:
- Ranking aktualizowany automatycznie gdy użytkownik nawiguje do sekcji (:ranking)
- Performance score przeliczany automatycznie po zakończeniu każdej symulacji (w Simulations context)

## 7. Integracja API

### Strategies.list_strategies/2 (z sortowaniem)

**Request**:
```elixir
Strategies.list_strategies(user, sort: "performance_score", order: "asc")
```

**Response**:
```elixir
[
  %Strategy{
    id: "uuid",
    name: "Hot Numbers Focus",
    type: :manual,
    performance_score: 85430.5,   # najniższy = najlepszy
    description: "...",
    ...
  },
  %Strategy{
    id: "uuid",
    name: "Balanced Mix",
    type: :ai_generated,
    performance_score: 125430.5,
    ...
  },
  %Strategy{
    id: "uuid",
    name: "New Strategy",
    type: :manual,
    performance_score: nil,        # brak symulacji
    ...
  }
]
```

**Implementacja** (w Strategies context):
```elixir
def list_strategies(user, opts \\ []) do
  query = from s in Strategy,
    where: s.user_id == ^user.id and s.status == :active
  
  query = apply_sort(query, opts[:sort], opts[:order])
  
  Repo.all(query)
end

defp apply_sort(query, "performance_score", "asc") do
  from s in query,
    order_by: [asc_nulls_last: s.performance_score]  # nil na końcu
end

defp apply_sort(query, "performance_score", "desc") do
  from s in query,
    order_by: [desc_nulls_last: s.performance_score]  # nil na końcu
end

defp apply_sort(query, _, _) do
  from s in query, order_by: [desc: s.inserted_at]  # default
end
```

### Update performance score (wywoływane po symulacji)

**Request** (w Simulations context po zakończeniu symulacji):
```elixir
Strategies.update_performance_score(strategy_id)
```

**Response**:
```elixir
{:ok, new_score} | {:ok, nil}
```

**Implementacja**:
```elixir
def update_performance_score(strategy_id) do
  # Oblicz medianę liczby prób dla wszystkich udanych symulacji
  median = from(sim in Simulation,
    where: sim.strategy_id == ^strategy_id and sim.status == :success,
    select: fragment("percentile_cont(0.5) WITHIN GROUP (ORDER BY ?)", sim.attempts_count)
  )
  |> Repo.one()
  
  # Aktualizuj strategię
  from(s in Strategy, where: s.id == ^strategy_id)
  |> Repo.update_all(set: [performance_score: median])
  
  {:ok, median}
end
```

## 8. Interakcje użytkownika

### Przeglądanie rankingu

**Interakcja**: Scrollowanie listy rankingowej
- Lista jest statyczna (brak paginacji w MVP)
- Sortowanie: najlepsze (najniższy score) na górze
- Wizualne wyróżnienie top 3

**Brak interakcji**: Widok jest read-only, brak klikanych elementów poza nawigacją

### Nawigacja do symulacji (z unranked card)

**Trigger**: Kliknięcie "Uruchom symulację" na karcie nierangowanej
- Event: `phx-click="navigate"` z `phx-value-section="simulations"`
- Handler: `handle_event("navigate", ...)` w PageLive
- Rezultat: Przełączenie na sekcję symulacji

### Kliknięcie strategii dla szczegółów

**Trigger**: Kliknięcie karty strategii (przyszła funkcjonalność)
- Otwarcie modala ze szczegółami strategii
- Wyświetlenie pełnych reguł (rules)
- Historia symulacji dla tej strategii
- Wykres wydajności w czasie
- Akcje: Edytuj, Usuń, Uruchom symulację, Klonuj

**Implementacja** (do dodania w przyszłości):
- Event: `phx-click="view_strategy_details"` z `phx-value-id`
- Modal z zakładkami: Szczegóły, Reguły, Historia symulacji
- Możliwość bezpośredniego uruchomienia symulacji z tego miejsca

## 9. Warunki i walidacja

### Warunek renderowania empty state

**Sprawdzany w**: `ranking_section/1`

**Warunek**:
```elixir
ranked_strategies = 
  strategies
  |> Enum.reject(&is_nil(&1.performance_score))

ranked_strategies == []
```

**Wpływ na UI**:
- Jeśli brak strategii z performance score → empty state
- Empty state zawiera komunikat i przycisk CTA do symulacji

### Warunek wyróżnienia top 3

**Sprawdzany w**: `ranking_card/1`

**Warunek**: `position <= 3`

**Wpływ na UI**:
- Pozycja #1:
  - Ring: `ring-2 ring-warning`
  - Kolor tekstu: `text-warning`
  - Ikona trofeum: złota
- Pozycja #2:
  - Ring: `ring-2 ring-base-300`
  - Kolor tekstu: `text-base-300`
  - Ikona trofeum: srebrna
- Pozycja #3:
  - Ring: `ring-2 ring-amber-700`
  - Kolor tekstu: `text-amber-700`
  - Ikona trofeum: brązowa
- Pozycja > 3:
  - Brak ring
  - Standardowy kolor tekstu
  - Brak ikony

### Warunek renderowania divider i unranked cards

**Sprawdzany w**: `ranking_section/1`

**Warunek**:
```elixir
unranked_strategies != []
```

**Wpływ na UI**:
- Jeśli są strategie bez performance score → renderuj divider + unranked cards
- Jeśli wszystkie mają score → brak divider

### Sortowanie ascending (niższy score = lepszy)

**Dlaczego**: Niższy performance score oznacza mniejszą medianę liczby prób, czyli szybsze trafienie → lepsza strategia

**Implementacja**:
```elixir
Enum.sort_by(strategies, & &1.performance_score, :asc)
```

## 10. Obsługa błędów

### Błąd - brak strategii

**Scenariusz**: Nowy użytkownik bez żadnych strategii

**Obsługa**: Empty state
```heex
<.empty_state icon="hero-trophy">
  <:title>Brak danych rankingowych</:title>
  <:description>Uruchom symulacje aby zobaczyć ranking strategii</:description>
  <:action>
    <button phx-click="navigate" phx-value-section="simulations" class="btn btn-primary btn-lg">
      Uruchom symulację
    </button>
  </:action>
</.empty_state>
```

**UI**: Przyjazny komunikat z akcją

### Błąd - wszystkie strategie bez performance score

**Scenariusz**: User ma strategie, ale nie uruchomił jeszcze żadnej symulacji

**Obsługa**: Empty state jak powyżej + lista unranked strategies poniżej (opcjonalnie)

**UI**: 
- Empty state dla rankingu
- Komunikat "Strategie bez symulacji" + lista z przyciskami CTA

### Błąd - performance score jest ujemny lub nieprawidłowy

**Scenariusz**: Błąd w obliczeniach lub uszkodzone dane

**Obsługa** (walidacja w schema):
```elixir
def changeset(strategy, attrs) do
  strategy
  |> cast(attrs, [:performance_score, ...])
  |> validate_number(:performance_score, greater_than_or_equal_to: 0)
end
```

**UI**: Wyświetlenie "—" lub "Błąd danych" zamiast nieprawidłowego score

### Błąd - brak dostępu do strategii innych użytkowników

**Scenariusz**: Teoretyczna próba manipulacji

**Obsługa**: Automatyczne filtrowanie przez `where: s.user_id == ^user.id` w query

**UI**: User widzi tylko swoje strategie (brak możliwości błędu w UI)

## 11. Kroki implementacji

### Krok 1: Przygotowanie struktury

1.1. W `lib/numbers_evolution_web/components/sections_components.ex` dodać:
```elixir
attr :strategies, :list, required: true

def ranking_section(assigns) do
  # Przygotowanie danych
  ranked_strategies =
    assigns.strategies
    |> Enum.reject(&is_nil(&1.performance_score))
    |> Enum.sort_by(& &1.performance_score, :asc)
  
  unranked_strategies =
    assigns.strategies
    |> Enum.filter(&is_nil(&1.performance_score))
  
  assigns =
    assigns
    |> assign(:ranked_strategies, ranked_strategies)
    |> assign(:unranked_strategies, unranked_strategies)
  
  # Template
  ~H"""
  <%!-- Content będzie w kolejnych krokach --%>
  """
end
```

### Krok 2: Implementacja nagłówka i empty state

2.1. Dodać nagłówek:
```heex
<div class="space-y-8">
  <h1 class="text-4xl font-bold">Ranking Strategii</h1>
```

2.2. Dodać empty state:
```heex
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
<% end %>
```

### Krok 3: Implementacja listy rankingowej

3.1. Dodać listę ranked strategies:
```heex
<% else %>
  <div class="space-y-4">
    <%= for {strategy, index} <- Enum.with_index(@ranked_strategies, 1) do %>
      <.ranking_card strategy={strategy} position={index} />
    <% end %>
    
    <%!-- Unranked strategies --%>
    <%= if @unranked_strategies != [] do %>
      <div class="divider">Strategie bez symulacji</div>
      <%= for strategy <- @unranked_strategies do %>
        <.unranked_strategy_card strategy={strategy} />
      <% end %>
    <% end %>
  </div>
<% end %>
```

### Krok 4: Implementacja ranking_card

4.1. Dodać subkomponent:
```elixir
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
      <%!-- Pozycja --%>
      <div class={[
        "text-3xl font-bold w-12 text-center",
        @position == 1 && "text-warning",
        @position == 2 && "text-base-300",
        @position == 3 && "text-amber-700"
      ]}>
        #{@position}
      </div>
      
      <%!-- Treść --%>
      <div class="flex-1">
        <div class="flex items-center gap-2 mb-2">
          <%!-- Ikona trofeum (tylko dla top 3) --%>
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
        
        <%!-- Performance Score --%>
        <div class="stats stats-horizontal shadow">
          <div class="stat">
            <div class="stat-title">Performance Score</div>
            <div class="stat-value text-primary">
              {Float.round(@strategy.performance_score, 2)}
            </div>
            <div class="stat-desc">Mediana liczby prób</div>
          </div>
        </div>
      </div>
    </div>
  </.card>
  """
end
```

### Krok 5: Implementacja unranked_strategy_card

5.1. Dodać subkomponent:
```elixir
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
```

### Krok 6: Event handler ładowania w PageLive

6.1. Dodać funkcję ładowania danych:
```elixir
defp load_ranking(socket) do
  user = socket.assigns.current_user
  
  strategies =
    if user,
      do: Strategies.list_strategies(user, sort: "performance_score", order: "asc"),
      else: []
  
  assign(socket, :strategies, strategies)
end

defp load_section_data(socket, :ranking), do: load_ranking(socket)
# ... reszta load_section_data dla innych sekcji
```

### Krok 7: Sortowanie w Strategies context

7.1. Zaktualizować `apply_sort/3` w Strategies context:
```elixir
defp apply_sort(query, "performance_score", "asc") do
  from s in query,
    order_by: [asc_nulls_last: s.performance_score]
end

defp apply_sort(query, "performance_score", "desc") do
  from s in query,
    order_by: [desc_nulls_last: s.performance_score]
end

defp apply_sort(query, "name", "asc") do
  from s in query, order_by: [asc: s.name]
end

defp apply_sort(query, _, _) do
  from s in query, order_by: [desc: s.inserted_at]
end
```

### Krok 8: Implementacja update_performance_score

8.1. W `lib/numbers_evolution/strategies.ex` dodać:
```elixir
def update_performance_score(strategy_id) do
  # Oblicz medianę z udanych symulacji
  median_query = from sim in Simulation,
    where: sim.strategy_id == ^strategy_id and sim.status == :success,
    select: fragment("percentile_cont(0.5) WITHIN GROUP (ORDER BY ?)", sim.attempts_count)
  
  median = Repo.one(median_query)
  
  # Aktualizuj strategię
  result = from(s in Strategy, where: s.id == ^strategy_id)
  |> Repo.update_all(set: [performance_score: median])
  
  case result do
    {1, _} -> {:ok, median}
    _ -> {:error, :strategy_not_found}
  end
end
```

8.2. Wywołanie z Simulations context (po zakończeniu symulacji):
```elixir
defp finalize_simulation(simulation, result, start_time) do
  # ... zapisz wynik symulacji
  
  case result do
    {:success, _, _} ->
      # Zaktualizuj performance score strategii
      Strategies.update_performance_score(simulation.strategy_id)
    
    _ -> :ok
  end
end
```

### Krok 9: Testowanie

9.1. Testy sortowania:
```elixir
describe "list_strategies/2 with performance_score sorting" do
  test "sorts strategies by performance_score ascending (best first)", %{user: user} do
    strategy1 = insert(:strategy, user: user, performance_score: 150000.0)
    strategy2 = insert(:strategy, user: user, performance_score: 100000.0)  # najlepszy
    strategy3 = insert(:strategy, user: user, performance_score: 200000.0)
    strategy4 = insert(:strategy, user: user, performance_score: nil)       # brak danych
    
    strategies = Strategies.list_strategies(user, sort: "performance_score", order: "asc")
    
    assert [s2, s1, s3, s4] = strategies
    assert s2.id == strategy2.id  # 100k - najlepszy
    assert s1.id == strategy1.id  # 150k
    assert s3.id == strategy3.id  # 200k
    assert s4.id == strategy4.id  # nil na końcu
  end
end
```

9.2. Testy update_performance_score:
```elixir
describe "update_performance_score/1" do
  test "calculates median from successful simulations", %{strategy: strategy} do
    # Utwórz 5 symulacji z różnymi attempts_count
    insert(:simulation, strategy: strategy, status: :success, attempts_count: 100)
    insert(:simulation, strategy: strategy, status: :success, attempts_count: 200)
    insert(:simulation, strategy: strategy, status: :success, attempts_count: 300)
    insert(:simulation, strategy: strategy, status: :success, attempts_count: 400)
    insert(:simulation, strategy: strategy, status: :success, attempts_count: 500)
    
    # Mediana = 300
    assert {:ok, 300.0} = Strategies.update_performance_score(strategy.id)
    
    updated_strategy = Repo.get(Strategy, strategy.id)
    assert updated_strategy.performance_score == 300.0
  end
  
  test "ignores failed simulations", %{strategy: strategy} do
    insert(:simulation, strategy: strategy, status: :success, attempts_count: 100)
    insert(:simulation, strategy: strategy, status: :timeout, attempts_count: 1000000)  # ignored
    insert(:simulation, strategy: strategy, status: :success, attempts_count: 200)
    
    # Mediana = 150 (tylko z success)
    assert {:ok, 150.0} = Strategies.update_performance_score(strategy.id)
  end
  
  test "sets nil when no successful simulations", %{strategy: strategy} do
    insert(:simulation, strategy: strategy, status: :timeout)
    insert(:simulation, strategy: strategy, status: :error)
    
    assert {:ok, nil} = Strategies.update_performance_score(strategy.id)
  end
end
```

9.3. Testy LiveView:
```elixir
test "displays ranked strategies sorted by performance", %{conn: conn} do
  user = insert(:user)
  strategy1 = insert(:strategy, user: user, name: "Best", performance_score: 100.0)
  strategy2 = insert(:strategy, user: user, name: "Medium", performance_score: 200.0)
  strategy3 = insert(:strategy, user: user, name: "No data", performance_score: nil)
  
  conn = log_in_user(conn, user)
  {:ok, view, _html} = live(conn, "/")
  
  view |> element("button", "Ranking") |> render_click()
  
  html = render(view)
  
  # Sprawdź kolejność
  assert html =~ ~r/Best.*Medium/s
  
  # Sprawdź top 3 wyróżnienia
  assert has_element?(view, ".text-warning", "#1")  # złoty dla #1
  
  # Sprawdź unranked strategy
  assert html =~ "No data"
  assert html =~ "Brak danych"
end

test "shows empty state when no strategies with performance score", %{conn: conn} do
  user = insert(:user)
  insert(:strategy, user: user, performance_score: nil)
  insert(:strategy, user: user, performance_score: nil)
  
  conn = log_in_user(conn, user)
  {:ok, view, _html} = live(conn, "/")
  
  view |> element("button", "Ranking") |> render_click()
  
  assert render(view) =~ "Brak danych rankingowych"
  assert has_element?(view, "button", "Uruchom symulację")
end
```

### Krok 10: Styling i optymalizacje

10.1. Dodać klasy Tailwind dla responsywności:
- Karty: pełna szerokość na mobile, max-width na desktop
- Pozycja w rankingu: mniejsza na mobile (`text-2xl md:text-3xl`)

10.2. Dodać animacje (opcjonalnie):
```css
/* app.css */
.ranking-card {
  @apply transition-all duration-200;
}

.ranking-card:hover {
  @apply scale-102 shadow-2xl;
}
```

10.3. Rozważyć limit wyświetlanych strategii:
- Top 10 domyślnie
- Przycisk "Pokaż więcej" dla pełnej listy (opcjonalnie)

10.4. Dodać tooltip z dodatkowymi informacjami (opcjonalnie):
- Liczba symulacji użyta do obliczenia
- Średnia, min, max attempts_count

---

**Status implementacji**: ✅ Kompletna struktura zaimplementowana
**Priorytet dla MVP**: ŚREDNI (widok read-only, pomocniczy)
**Zależności**: Wymaga działającego `Strategies` context z performance_score
**Następne kroki**: Testowanie, opcjonalne ulepszenia UI (animacje, tooltips)

