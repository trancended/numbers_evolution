# Plan implementacji widoku Dashboard

## 1. Przegląd

Dashboard jest głównym centrum kontroli aplikacji Numbers Evolution, wyświetlanym po zalogowaniu użytkownika. Jego celem jest zaprezentowanie kluczowych statystyk użytkownika, umożliwienie szybkiego dostępu do głównych funkcjonalności oraz wyświetlenie ostatnich symulacji. Dashboard działa jako punkt startowy dla wszystkich działań użytkownika w aplikacji.

## 2. Routing widoku

Widok dostępny na głównej ścieżce `/` z parametrem `@active_section = :dashboard` (przypisywanym automatycznie po zalogowaniu przez `get_initial_section/1`).

**Routing**:
- URL: `/`
- LiveView: `NumbersEvolutionWeb.PageLive`
- Komponent: `dashboard_section/1` z `NumbersEvolutionWeb.PageComponents`
- Dostęp: Wymagana autentykacja (sprawdzane przez `mount/3`)

## 3. Struktura komponentów

```
PageLive (LiveView - kontener główny)
└── dashboard_section (function component)
    ├── Nagłówek z powitaniem
    ├── Stats cards (4 karty statystyk)
    │   └── stat_card × 4 (subkomponent)
    ├── Quick actions (karta z przyciskami akcji)
    └── Recent simulations (karta z ostatnimi symulacjami)
        ├── Empty state (gdy brak symulacji)
        └── simulations_table (gdy są symulacje)
```

## 4. Szczegóły komponentów

### Dashboard Section (dashboard_section/1)

**Opis komponentu**: Główny kontener sekcji dashboard, który zarządza układem i deleguje renderowanie do subkomponentów. Wyświetla statystyki użytkownika, szybkie akcje i ostatnie symulacje.

**Główne elementy HTML i komponenty dzieci**:
- `<div class="space-y-8">` - kontener główny z odstępami
- `<h1>` - tytuł "Dashboard"
- `<p>` - powitanie z emailem użytkownika
- Grid z 4 kartami statystyk (`stat_card × 4`)
- Karta z quick actions (3 przyciski do nawigacji)
- Karta z ostatnimi symulacjami (tabela lub empty state)

**Obsługiwane zdarzenia**:
- `phx-click="navigate"` z `phx-value-section` - nawigacja do innych sekcji (obsługiwana w PageLive)
- Brak lokalnych zdarzeń specyficznych dla dashboard

**Warunki walidacji**:
- Brak walidacji formularzy (dashboard jest read-only)
- Warunek renderowania: `@current_user` musi istnieć (sprawdzane na poziomie PageLive)

**Typy**:
- Props:
  - `current_user :: %NumbersEvolution.Accounts.User{}`
  - `user_stats :: map()` (kształt: `%{strategies_count, simulations_count, best_strategy}`)
  - `recent_simulations :: list(Simulation.t())`

**Propsy**:
```elixir
attr :current_user, :map, required: true
attr :user_stats, :map, default: %{strategies_count: 0, simulations_count: 0, best_strategy: nil}
attr :recent_simulations, :list, default: []
```

### Stat Card (stat_card/1)

**Opis komponentu**: Subkomponent wyświetlający pojedynczą statystykę użytkownika z ikoną, tytułem i wartością. Używa DaisyUI `stats` component.

**Główne elementy HTML**:
- `<div class="stats shadow">` - kontener DaisyUI
- `<div class="stat">` - pojedyncza statystyka
- `<div class="stat-figure">` - ikona (Heroicons)
- `<div class="stat-title">` - tytuł statystyki
- `<div class="stat-value">` - wartość statystyki

**Obsługiwane zdarzenia**: Brak (komponent czysto prezentacyjny)

**Warunki walidacji**: Brak

**Typy**:
```elixir
attr :icon, :string, required: true        # np. "hero-light-bulb"
attr :title, :string, required: true       # np. "Strategie"
attr :value, :string, required: true       # np. "5"
```

**Propsy**: Jak w typach powyżej

### Empty State (wbudowany w dashboard_section)

**Opis komponentu**: Wyświetlany gdy użytkownik nie ma żadnych symulacji. Zawiera ikonę, komunikat i przycisk CTA.

**Główne elementy HTML**:
- Ikona `hero-chart-bar` (opacity-30)
- Tekst "Nie masz jeszcze żadnych symulacji"
- Przycisk "Uruchom pierwszą symulację" z nawigacją do sekcji :simulations

**Obsługiwane zdarzenia**:
- `phx-click="navigate"` z `phx-value-section="simulations"`

**Warunki walidacji**: Renderowany gdy `@recent_simulations == []`

## 5. Typy

### UserStats (backend context)

```elixir
# Zwracany przez Accounts.get_user_stats/1
%{
  strategies_count: non_neg_integer(),
  simulations_count: non_neg_integer(),
  best_strategy: %{
    id: binary(),
    name: String.t(),
    performance_score: float() | nil
  } | nil
}
```

### Simulation (Ecto schema)

```elixir
defmodule NumbersEvolution.Simulations.Simulation do
  use Ecto.Schema

  schema "simulations" do
    field :status, Ecto.Enum, values: [:pending, :running, :success, :timeout, :error]
    field :result, :map  # JSONB
    belongs_to :strategy, NumbersEvolution.Strategies.Strategy
    belongs_to :target_draw, NumbersEvolution.Draws.Draw
    belongs_to :user, NumbersEvolution.Accounts.User
    
    timestamps(type: :utc_datetime)
  end
end
```

### User (Ecto schema)

```elixir
defmodule NumbersEvolution.Accounts.User do
  use Ecto.Schema

  schema "users" do
    field :email, :string
    field :hashed_password, :string
    
    has_many :strategies, NumbersEvolution.Strategies.Strategy
    has_many :simulations, NumbersEvolution.Simulations.Simulation
    
    timestamps(type: :utc_datetime)
  end
end
```

## 6. Zarządzanie stanem

**Architektura stanu**: Centralne zarządzanie stanem w `PageLive`, komponenty są bezstanowe (stateless function components).

**Stan zarządzany w PageLive**:
```elixir
# W mount/3 i load_dashboard_data/1
socket
|> assign(:current_user, user)                    # User struct z sesji
|> assign(:active_section, :dashboard)            # Aktywna sekcja
|> assign(:user_stats, stats)                     # Statystyki z Accounts context
|> assign(:recent_simulations, simulations)       # Ostatnie 5 symulacji
```

**Ładowanie danych**:
```elixir
defp load_dashboard_data(socket) do
  user = socket.assigns.current_user
  
  if user do
    stats = Accounts.get_user_stats(user)
    recent_simulations = Simulations.list_simulations(user, limit: 5)
    
    socket
    |> assign(:user_stats, stats)
    |> assign(:recent_simulations, recent_simulations)
  else
    socket
  end
end
```

**Custom hooki**: Nie są wymagane (całe zarządzanie stanem w PageLive)

**Wzorzec odświeżania**:
- Dane ładowane przy pierwszym załadowaniu w `mount/3`
- Odświeżane przy nawigacji do dashboard przez `handle_event("navigate", %{"section" => "dashboard"})`
- Automatyczna aktualizacja przez LiveView przy zmianach w bazie (opcjonalnie przez PubSub)

## 7. Integracja API

Dashboard korzysta z kontekstów Phoenix (nie bezpośrednich wywołań API):

### Accounts.get_user_stats/1

**Request**:
```elixir
Accounts.get_user_stats(user)
# user :: %User{}
```

**Response**:
```elixir
%{
  strategies_count: 5,
  simulations_count: 23,
  best_strategy: %{
    id: "uuid",
    name: "Hot Numbers Focus",
    performance_score: 125430.5
  }
}
```

**Implementacja** (backend):
```elixir
def get_user_stats(user) do
  strategies_count = Repo.aggregate(
    from(s in Strategy, where: s.user_id == ^user.id),
    :count
  )
  
  simulations_count = Repo.aggregate(
    from(sim in Simulation, where: sim.user_id == ^user.id),
    :count
  )
  
  best_strategy = 
    from(s in Strategy,
      where: s.user_id == ^user.id and not is_nil(s.performance_score),
      order_by: [asc: s.performance_score],
      limit: 1
    )
    |> Repo.one()
  
  %{
    strategies_count: strategies_count,
    simulations_count: simulations_count,
    best_strategy: best_strategy
  }
end
```

### Simulations.list_simulations/2

**Request**:
```elixir
Simulations.list_simulations(user, limit: 5)
```

**Response**:
```elixir
[
  %Simulation{
    id: "uuid",
    status: :success,
    result: %{"attempts_count" => 125430},
    strategy_id: "uuid",
    target_draw_id: "uuid",
    inserted_at: ~U[2025-11-15 10:00:00Z]
  },
  # ... więcej
]
```

## 8. Interakcje użytkownika

### Nawigacja do sekcji

**Trigger**: Kliknięcie przycisku quick action
**Event**: `phx-click="navigate"` z `phx-value-section="strategies"`
**Handler** (w PageLive):
```elixir
def handle_event("navigate", %{"section" => section}, socket) do
  section_atom = String.to_existing_atom(section)
  
  socket =
    socket
    |> assign(:active_section, section_atom)
    |> load_section_data(section_atom)
  
  {:noreply, socket}
end
```
**Rezultat**: Przełączenie widoku na wybraną sekcję bez przeładowania strony

### Przeglądanie szczegółów symulacji

**Trigger**: Kliknięcie wiersza w tabeli symulacji
**Event**: Opcjonalny `phx-click` na wierszu (może otworzyć modal ze szczegółami)
**Rezultat**: Wyświetlenie szczegółowych informacji o symulacji

## 9. Warunki i walidacja

### Warunek renderowania dashboard

**Sprawdzany w**: `PageLive.render/1`
```elixir
<%= if @current_user do %>
  <.navbar ... />
  <main>
    <%= case @active_section do %>
      <% :dashboard -> %>
        <.dashboard_section 
          current_user={@current_user}
          user_stats={@user_stats}
          recent_simulations={@recent_simulations}
        />
```

**Walidacja**: `@current_user` musi być różny od `nil`

**Wpływ na UI**: Jeśli brak użytkownika → wyświetlana jest `landing_section`

### Warunek wyświetlania empty state

**Sprawdzany w**: `dashboard_section/1`
```elixir
<%= if @recent_simulations == [] do %>
  <div class="text-center py-8">
    <%!-- Empty state --%>
  </div>
<% else %>
  <%!-- Tabela symulacji --%>
<% end %>
```

**Walidacja**: Lista `@recent_simulations` jest pusta

**Wpływ na UI**: Różna treść w sekcji "Ostatnie symulacje"

### Warunek wyświetlania best_strategy

**Sprawdzany w**: `stat_card` dla "Najlepsza strategia"
```elixir
value={if best_strategy = Map.get(@user_stats, :best_strategy), 
  do: best_strategy.name, 
  else: "—"}
```

**Walidacja**: `best_strategy` w `user_stats` może być `nil`

**Wpływ na UI**: Wyświetlenie nazwy strategii lub placeholder "—"

## 10. Obsługa błędów

### Błąd ładowania statystyk

**Scenariusz**: Błąd bazy danych przy `Accounts.get_user_stats/1`

**Obsługa**:
```elixir
defp load_dashboard_data(socket) do
  user = socket.assigns.current_user
  
  if user do
    try do
      stats = Accounts.get_user_stats(user)
      recent_simulations = Simulations.list_simulations(user, limit: 5)
      
      socket
      |> assign(:user_stats, stats)
      |> assign(:recent_simulations, recent_simulations)
    rescue
      e ->
        Logger.error("Failed to load dashboard data: #{inspect(e)}")
        
        socket
        |> put_flash(:error, "Nie udało się załadować danych dashboard")
        |> assign(:user_stats, %{strategies_count: 0, simulations_count: 0, best_strategy: nil})
        |> assign(:recent_simulations, [])
    end
  else
    socket
  end
end
```

**UI**: Flash message z błędem, wyświetlenie pustych statystyk (0/0/brak)

### Błąd sesji (utrata autentykacji)

**Scenariusz**: Token sesji wygasł lub nieprawidłowy

**Obsługa** (w `mount/3`):
```elixir
defp get_current_user(session) do
  case Map.get(session, "user_token") do
    token when is_binary(token) ->
      case Accounts.verify_user_token(token) do
        {:ok, user} -> user
        {:error, _} -> nil
      end
    _ -> nil
  end
end
```

**UI**: Automatyczne przekierowanie na landing page z formularzem logowania

### Brak danych do wyświetlenia

**Scenariusz**: Nowy użytkownik bez strategii i symulacji

**Obsługa**: Graceful degradation przez empty states i wartości domyślne

**UI**: 
- Statystyki pokazują "0" lub "—"
- Empty state w sekcji symulacji z przyciskiem CTA
- Przyciski quick actions pozostają aktywne

## 11. Kroki implementacji

### Krok 1: Przygotowanie struktury

1.1. Utworzyć plik `lib/numbers_evolution_web/components/page_components.ex` (już istnieje)

1.2. Zdefiniować funkcję komponentu `dashboard_section/1` z atrybutami:
```elixir
attr :current_user, :map, required: true
attr :user_stats, :map, default: %{strategies_count: 0, simulations_count: 0, best_strategy: nil}
attr :recent_simulations, :list, default: []
```

### Krok 2: Implementacja komponentu stat_card

2.1. Dodać prywatny subkomponent `stat_card/1`:
```elixir
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
```

### Krok 3: Implementacja sekcji głównej

3.1. Dodać nagłówek i powitanie:
```heex
<div class="space-y-8">
  <h1 class="text-4xl font-bold">Dashboard</h1>
  <p class="text-lg">Witaj, {@current_user.email}</p>
```

3.2. Dodać grid ze statystykami:
```heex
<div class="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
  <.stat_card icon="hero-light-bulb" title="Strategie" value={to_string(@user_stats.strategies_count)} />
  <.stat_card icon="hero-chart-bar" title="Symulacje" value={to_string(@user_stats.simulations_count)} />
  <.stat_card icon="hero-trophy" title="Najlepsza" value={...} />
  <.stat_card icon="hero-calendar" title="Ostatnia aktywność" value="Dzisiaj" />
</div>
```

### Krok 4: Implementacja Quick Actions

4.1. Dodać kartę z przyciskami akcji:
```heex
<div class="card bg-base-200">
  <div class="card-body">
    <h2 class="card-title">Szybkie akcje</h2>
    <div class="grid md:grid-cols-3 gap-4 mt-4">
      <button phx-click="navigate" phx-value-section="strategies" class="btn btn-primary btn-lg">
        <.icon name="hero-plus-circle" class="size-6" /> Utwórz nową strategię
      </button>
      <%!-- pozostałe przyciski --%>
    </div>
  </div>
</div>
```

### Krok 5: Implementacja Recent Simulations

5.1. Dodać kartę z warunkiem empty state:
```heex
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Ostatnie symulacje</h2>
    <%= if @recent_simulations == [] do %>
      <div class="text-center py-8">
        <.icon name="hero-chart-bar" class="size-16 mx-auto mb-4 opacity-30" />
        <p>Nie masz jeszcze żadnych symulacji</p>
        <button phx-click="navigate" phx-value-section="simulations" class="btn btn-primary mt-4">
          Uruchom pierwszą symulację
        </button>
      </div>
    <% else %>
      <%!-- Tabela symulacji --%>
    <% end %>
  </div>
</div>
```

5.2. Dodać tabelę symulacji (dla else):
```heex
<div class="overflow-x-auto">
  <table class="table table-zebra">
    <thead>
      <tr>
        <th>Strategia</th>
        <th>Data</th>
        <th>Próby</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>
      <%= for sim <- @recent_simulations do %>
        <tr>
          <td>{sim.strategy_id}</td>
          <td>{Calendar.strftime(sim.inserted_at, "%Y-%m-%d %H:%M")}</td>
          <td>{(sim.result && sim.result["attempts_count"]) || "—"}</td>
          <td><.status_indicator status={sim.status} /></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

### Krok 6: Integracja z PageLive

6.1. W `page_live.ex` dodać import:
```elixir
import NumbersEvolutionWeb.PageComponents
```

6.2. W `render/1` dodać case dla dashboard:
```elixir
<% :dashboard -> %>
  <.dashboard_section
    current_user={@current_user}
    user_stats={@user_stats || %{}}
    recent_simulations={@recent_simulations || []}
  />
```

6.3. Dodać funkcję ładującą dane:
```elixir
defp load_dashboard_data(socket) do
  user = socket.assigns.current_user
  
  if user do
    stats = Accounts.get_user_stats(user)
    recent_simulations = Simulations.list_simulations(user, limit: 5)
    
    socket
    |> assign(:user_stats, stats)
    |> assign(:recent_simulations, recent_simulations)
  else
    socket
  end
end
```

### Krok 7: Implementacja backend contexts

7.1. W `lib/numbers_evolution/accounts.ex` dodać:
```elixir
def get_user_stats(user) do
  strategies_count = Repo.aggregate(
    from(s in Strategy, where: s.user_id == ^user.id),
    :count
  )
  
  simulations_count = Repo.aggregate(
    from(sim in Simulation, where: sim.user_id == ^user.id),
    :count
  )
  
  best_strategy = 
    from(s in Strategy,
      where: s.user_id == ^user.id and not is_nil(s.performance_score),
      order_by: [asc: s.performance_score],
      limit: 1,
      select: %{id: s.id, name: s.name, performance_score: s.performance_score}
    )
    |> Repo.one()
  
  %{
    strategies_count: strategies_count,
    simulations_count: simulations_count,
    best_strategy: best_strategy
  }
end
```

### Krok 8: Styling i responsywność

8.1. Dodać klasy Tailwind dla responsywności:
- Stats cards: `grid md:grid-cols-2 lg:grid-cols-4`
- Quick actions: `grid md:grid-cols-3`

8.2. Przetestować na różnych rozdzielczościach:
- Mobile (320px-768px): Single column layout
- Tablet (768px-1024px): 2 kolumny dla stats
- Desktop (>1024px): Pełny grid layout

### Krok 9: Testowanie

9.1. Testy jednostkowe dla `Accounts.get_user_stats/1`:
```elixir
test "returns correct user stats", %{user: user} do
  # Setup: utworzyć 3 strategie i 5 symulacji
  
  stats = Accounts.get_user_stats(user)
  
  assert stats.strategies_count == 3
  assert stats.simulations_count == 5
  assert stats.best_strategy != nil
end

test "returns nil for best_strategy when no strategies exist" do
  user = insert(:user)
  stats = Accounts.get_user_stats(user)
  
  assert stats.best_strategy == nil
end
```

9.2. Testy LiveView:
```elixir
test "dashboard displays user stats", %{conn: conn, user: user} do
  {:ok, view, _html} = live(conn, "/")
  
  assert render(view) =~ "Dashboard"
  assert render(view) =~ user.email
  assert render(view) =~ "Strategie"
end

test "dashboard shows empty state for new user", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/")
  
  assert render(view) =~ "Nie masz jeszcze żadnych symulacji"
  assert has_element?(view, "button", "Uruchom pierwszą symulację")
end
```

### Krok 10: Optymalizacja i finalizacja

10.1. Dodać preloading dla związanych danych:
```elixir
Simulations.list_simulations(user, limit: 5)
|> Repo.preload(:strategy)
```

10.2. Dodać caching dla statystyk (opcjonalne):
```elixir
# Użyć ETS lub cachex dla user_stats z TTL 5 minut
```

10.3. Dodać metryki wydajności (opcjonalne):
```elixir
:telemetry.execute([:dashboard, :load], %{duration: duration}, %{user_id: user.id})
```

10.4. Code review i refactoring:
- Sprawdzić czy wszystkie komponenty są stateless
- Zweryfikować error handling
- Upewnić się że wszystkie klasy Tailwind są używane poprawnie

---

**Status implementacji**: ✅ Podstawowa wersja zaimplementowana
**Priorytet dla MVP**: WYSOKI (główny widok po zalogowaniu)
**Zależności**: Wymaga działającego `Accounts` i `Simulations` context

