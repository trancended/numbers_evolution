# Plan implementacji widoku Strategie

## 1. Przegląd

Sekcja Strategie jest najbardziej kompleksowym widokiem w aplikacji Numbers Evolution. Umożliwia użytkownikom pełne zarządzanie strategiami typowania (CRUD), tworzenie nowych strategii manualnie lub przez AI, oraz mieszanie istniejących strategii w hybrydowe rozwiązania. Jest to kluczowa sekcja, od której zależą wszystkie inne funkcjonalności aplikacji (symulacje, ranking, generator).

## 2. Routing widoku

Widok dostępny na głównej ścieżce `/` z parametrem `@active_section = :strategies`.

**Routing**:
- URL: `/`
- LiveView: `NumbersEvolutionWeb.PageLive`
- Komponent: `strategies_section/1` z `NumbersEvolutionWeb.SectionsComponents`
- Dostęp: Wymagana autentykacja

## 3. Struktura komponentów

```
PageLive (LiveView - kontener główny)
└── strategies_section (function component)
    ├── Nagłówek z tytułem i przyciskami akcji
    │   ├── Przycisk "Utwórz mix" (warunkowy)
    │   └── Przycisk "Nowa strategia"
    ├── Empty state (gdy brak strategii)
    │   └── CTA "Utwórz pierwszą strategię"
    ├── Grid kart strategii
    │   └── strategy_card × n (subkomponent)
    │       ├── Checkbox do selekcji
    │       ├── Nazwa i badge typu
    │       ├── Opis (opcjonalny)
    │       ├── Stats (performance score)
    │       └── Przyciski akcji (Szczegóły, Usuń)
    └── Modal formularza strategii
        ├── Taby: "Manualna" / "AI"
        ├── Tab "Manualna" - formularz parametrów
        └── Tab "AI" - pole tekstowe + generowanie
```

## 4. Szczegóły komponentów

### Strategies Section (strategies_section/1)

**Opis komponentu**: Główny kontener sekcji strategii, zarządzający listą strategii użytkownika, selekcją do miksowania i modalem tworzenia nowych strategii.

**Główne elementy HTML i komponenty dzieci**:
- Nagłówek `<h1>` + `<div>` z przyciskami akcji
- Warunkowy empty state (`<.empty_state>`)
- Grid kart strategii (`<div class="grid md:grid-cols-2 lg:grid-cols-3">`)
- Modal formularza (`<.modal>`) z tabami DaisyUI

**Obsługiwane zdarzenia**:
- `phx-click="open_strategy_form"` - otwiera modal formularza
- `phx-click="close_strategy_form"` - zamyka modal
- `phx-click="switch_strategy_tab"` z `phx-value-tab` - przełączanie tabów
- `phx-click="toggle_strategy_select"` z `phx-value-id` - zaznaczanie strategii do miksu
- `phx-click="delete_strategy"` z `phx-value-id` - usuwanie strategii
- `phx-click="create_mix"` - tworzenie miksu z zaznaczonych strategii (TODO)

**Warunki walidacji**:
- Przycisk "Utwórz mix" aktywny tylko gdy `length(@selected_strategies) >= 2`
- Empty state renderowany gdy `@strategies == []`

**Typy**:
```elixir
attr :strategies, :list, required: true           # list(Strategy.t())
attr :selected_strategies, :list, required: true  # list(binary()) - IDs
attr :show_strategy_form, :boolean, required: true
attr :strategy_form_tab, :atom, required: true   # :manual | :ai
```

**Propsy**: Jak w typach powyżej

### Strategy Card (strategy_card/1)

**Opis komponentu**: Karta pojedynczej strategii wyświetlająca kluczowe informacje: nazwę, typ, performance score i akcje. Zawiera checkbox do selekcji dla miksowania.

**Główne elementy HTML**:
- `<.card>` (z core_components)
- Checkbox selekcji (`<input type="checkbox">`)
- Nazwa (`<h3>`) + badge typu (`<.badge>`)
- Opis (`<p>`) - opcjonalny
- Stats box (`<div class="stats">`) z performance score
- Przyciski akcji (`<button>` × 2)

**Obsługiwane zdarzenia**:
- `phx-click="toggle_strategy_select"` z `phx-value-id` - na checkboxie
- `phx-click="delete_strategy"` z `phx-value-id` i `data-confirm` - usuwanie
- `phx-click="view_strategy_details"` z `phx-value-id` - otwarcie szczegółów (TODO)

**Warunki walidacji**:
- Checkbox `checked` gdy `@selected` == true
- Performance score wyświetlane tylko gdy nie nil (w przeciwnym razie "—")
- Opis wyświetlany tylko gdy nie nil (`:if={@strategy.description}`)

**Typy**:
```elixir
attr :strategy, :map, required: true    # Strategy.t()
attr :selected, :boolean, required: true
```

**Propsy**: Jak w typach powyżej

### Modal formularza strategii

**Opis komponentu**: Modal DaisyUI zawierający formularz tworzenia strategii z dwoma tabami: manualny i AI. Formularz manualny pozwala na szczegółową konfigurację reguł generowania liczb, w tym blacklist, ratio, wagi i ograniczenia dystrybucji.

**Główne elementy HTML**:
- `<.modal id="strategy-form-modal" show={@show_strategy_form}>`
- Taby DaisyUI (`<div class="tabs tabs-boxed">`)
- **Formularz manualny (tab :manual)**:
  - Input nazwy strategii
  - Textarea opisu
  - **Blacklist liczb** (pomijane przy generowaniu)
    - Multi-select lub textarea dla głównych (1-50)
    - Multi-select lub textarea dla euro (1-12)
  - **Ratio parzyste/nieparzyste**
    - 2 number inputs dla głównych (suma = 5)
    - 2 number inputs dla euro (suma = 2)
  - **Ratio low/high** dla głównych
    - 2 number inputs (1-25 vs 26-50, suma = 5)
  - **Wagi (hot, cold, random)**
    - 3 range sliders z live display
    - Walidacja sumy = 1.0
  - **Preferowane liczby**
    - Input dla hot numbers (główne)
    - Input dla cold numbers (główne)
    - Input dla preferowanych euro
  - **Ograniczenia dystrybucji**
    - Checkbox "Max 2 liczby w jednej dziesiątce"
    - Input max_consecutive (np. max 2 kolejne liczby)
- **Formularz AI (tab :ai)**:
  - Textarea promptu (500 znaków)
  - Lista przykładowych promptów (klikalne)
  - Przycisk "Generuj strategię"
  - Loader podczas generowania
  - Preview wygenerowanej strategii
  - Możliwość edycji przed zapisem
- Przyciski akcji (Zamknij, Zapisz)

**Obsługiwane zdarzenia**:
- `phx-click="switch_strategy_tab"` z `phx-value-tab` - przełączanie tabów
- `phx-click="close_strategy_form"` - zamykanie modala
- `phx-submit="create_manual_strategy"` - zapisanie strategii manualnej
- `phx-change="validate_manual_strategy"` - walidacja w czasie rzeczywistym
- `phx-click="generate_ai_strategy"` - generowanie przez AI
- `phx-submit="save_ai_strategy"` - zapisanie wygenerowanej strategii
- `phx-click="use_example_prompt"` z `phx-value-prompt` - wypełnienie przykładem

**Warunki walidacji** (dla formularza manualnego):
- Nazwa strategii: wymagana, max 255 znaków, unikalna dla użytkownika (opcjonalnie)
- Opis: opcjonalny, max 1000 znaków
- Blacklist liczb: 
  - Główne: zakres 1-50, max 25 liczb (musi zostać minimum 5)
  - Euro: zakres 1-12, max 6 liczb (musi zostać minimum 2)
- Ratio parzyste/nieparzyste:
  - Główne: suma musi być 5, każda wartość >= 0
  - Euro: suma musi być 2, każda wartość >= 0
- Ratio low/high (główne): suma musi być 5, każda wartość >= 0
- Wagi (hot, cold, random): 
  - Każda waga 0.0-1.0
  - Suma dokładnie 1.0 (tolerance ±0.001)
- Preferowane liczby: 
  - Główne hot/cold: w zakresie 1-50, max 10 każda
  - Euro: w zakresie 1-12, max 6
  - Nie mogą być na blacklist
- Max per decade: 1-5 (jeśli włączone)
- Max consecutive: 1-4 (jeśli włączone)

**Warunki walidacji** (dla formularza AI):
- Prompt: wymagany, min 10 znaków, max 500 znaków
- Rate limiting: max 5 generacji/dzień/user
- Wygenerowana strategia musi przejść walidację struktury JSON
- Wszystkie pola reguł muszą być prawidłowe

## 5. Typy

### Strategy (Ecto schema)

```elixir
defmodule NumbersEvolution.Strategies.Strategy do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    id: binary(),
    name: String.t(),
    type: :manual | :ai_generated,
    status: :active | :archived | :deleted,
    description: String.t() | nil,
    rules: map(),
    performance_score: float() | nil,
    ai_prompt: String.t() | nil,
    user_id: binary(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  schema "strategies" do
    field :name, :string
    field :type, Ecto.Enum, values: [:manual, :ai_generated]
    field :status, Ecto.Enum, values: [:active, :archived, :deleted], default: :active
    field :description, :string
    field :rules, :map  # JSONB
    field :performance_score, :float
    field :ai_prompt, :string
    
    belongs_to :user, NumbersEvolution.Accounts.User
    has_many :simulations, NumbersEvolution.Simulations.Simulation
    
    timestamps(type: :utc_datetime)
  end
  
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:name, :type, :description, :rules, :ai_prompt])
    |> validate_required([:name, :type, :rules])
    |> validate_length(:name, max: 255)
    |> validate_length(:ai_prompt, max: 500)
    |> validate_rules()
  end
  
  defp validate_rules(changeset) do
    # Walidacja struktury rules
    # - sprawdzenie sum ratio
    # - sprawdzenie sum weights
    # - sprawdzenie zakresów liczb
    changeset
  end
end
```

### Rules structure (JSONB)

```elixir
%{
  "main_numbers" => %{
    # Blacklist - liczby całkowicie pomijane przy generowaniu
    "blacklist" => [13, 26, 39],         # lista liczb 1-50 (opcjonalna)
    
    # Ratio parzyste/nieparzyste
    "ratio_even_odd" => [2, 3],          # [parzyste, nieparzyste], suma = 5
    
    # Ratio niskie/wysokie (1-25 vs 26-50)
    "ratio_low_high" => [3, 2],          # [low, high], suma = 5
    
    # Preferowane liczby
    "preferred_hot" => [7, 23, 34],      # lista liczb 1-50 (max 10)
    "preferred_cold" => [1, 50],         # lista liczb 1-50 (max 10)
    
    # Wagi dla źródeł liczb
    "weights" => %{
      "hot" => 0.4,                      # waga dla hot numbers
      "cold" => 0.2,                     # waga dla cold numbers
      "random" => 0.4                    # waga dla losowych
    },                                   # suma musi być 1.0 (±0.001)
    
    # Ograniczenia dystrybucji
    "max_per_decade" => 2,               # max liczb w jednej dziesiątce (1-10, 11-20, etc.)
    "max_consecutive" => 2               # max kolejnych liczb (np. 7,8 lub 23,24,25)
  },
  "euro_numbers" => %{
    # Blacklist euro
    "blacklist" => [13],                 # lista liczb 1-12 (opcjonalna)
    
    # Ratio parzyste/nieparzyste
    "ratio_even_odd" => [1, 1],          # [parzyste, nieparzyste], suma = 2
    
    # Preferowane liczby
    "preferred" => [3, 9],               # lista liczb 1-12 (max 6)
    
    # Wagi
    "weights" => %{
      "hot" => 0.5,                      # waga dla hot numbers
      "random" => 0.5                    # waga dla losowych
    }                                    # suma musi być 1.0 (±0.001)
  }
}
```

**Przykładowe strategie**:

1. **"Pomin połowę liczb"**:
```elixir
%{
  "main_numbers" => %{
    "blacklist" => [1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, ...],  # 25 liczb
    "ratio_even_odd" => [2, 3],
    "ratio_low_high" => [3, 2],
    "weights" => %{"hot" => 0.5, "cold" => 0.0, "random" => 0.5},
    "max_per_decade" => 5,
    "max_consecutive" => 5
  },
  "euro_numbers" => %{
    "blacklist" => [1, 3, 5, 7, 9, 11],  # 6 liczb
    "ratio_even_odd" => [1, 1],
    "weights" => %{"hot" => 0.5, "random" => 0.5}
  }
}
```

2. **"Dwie nieparzyste, reszta parzyste"**:
```elixir
%{
  "main_numbers" => %{
    "blacklist" => [],
    "ratio_even_odd" => [3, 2],          # 3 parzyste, 2 nieparzyste
    "ratio_low_high" => [2, 3],
    "weights" => %{"hot" => 0.3, "cold" => 0.2, "random" => 0.5},
    "max_per_decade" => 5,
    "max_consecutive" => 5
  },
  "euro_numbers" => %{
    "blacklist" => [],
    "ratio_even_odd" => [1, 1],
    "weights" => %{"hot" => 0.5, "random" => 0.5}
  }
}
```

3. **"Max 2 liczby w dziesiątce"**:
```elixir
%{
  "main_numbers" => %{
    "blacklist" => [],
    "ratio_even_odd" => [2, 3],
    "ratio_low_high" => [3, 2],
    "weights" => %{"hot" => 0.4, "cold" => 0.3, "random" => 0.3},
    "max_per_decade" => 2,               # KLUCZOWE: max 2 w dziesiątce
    "max_consecutive" => 1               # dodatkowo: nie może być kolejnych
  },
  "euro_numbers" => %{
    "blacklist" => [],
    "ratio_even_odd" => [1, 1],
    "weights" => %{"hot" => 0.6, "random" => 0.4}
  }
}
```

### AI Request/Response (dla generowania strategii)

**Request do AI API**:
```elixir
%{
  "prompt" => "Create a balanced strategy focusing on recent hot numbers",
  "game_type" => "eurojackpot",
  "historical_data" => %{
    "last_32_draws" => [...],
    "hot_numbers" => %{
      "main" => [7, 23, 34],
      "euro" => [3, 9]
    },
    "cold_numbers" => %{
      "main" => [1, 50],
      "euro" => [1]
    }
  },
  "user_best_strategies" => [...]  # opcjonalnie
}
```

**Response od AI**:
```elixir
%{
  "strategy_name" => "Balanced Hot Strategy",
  "description" => "A balanced approach focusing on hot numbers...",
  "reasoning" => "This strategy balances hot number trends...",
  "game_type" => "eurojackpot",
  "rules" => %{
    "main_numbers" => %{...},
    "euro_numbers" => %{...}
  }
}
```

## 6. Zarządzanie stanem

**Architektura stanu**: Centralne zarządzanie w `PageLive`, komponenty bezstanowe.

**Stan zarządzany w PageLive**:
```elixir
socket
|> assign(:strategies, [])                # lista strategii użytkownika
|> assign(:selected_strategies, [])       # IDs zaznaczonych do miksu
|> assign(:show_strategy_form, false)     # widoczność modala
|> assign(:strategy_form_tab, :manual)    # aktywny tab (:manual | :ai)
|> assign(:strategy_form, to_form(...))   # formularz changeset (TODO)
```

**Ładowanie danych**:
```elixir
defp load_strategies(socket) do
  user = socket.assigns.current_user
  strategies = if user, do: Strategies.list_strategies(user), else: []
  assign(socket, :strategies, strategies)
end
```

**Event handlers w PageLive**:
```elixir
# Otwieranie/zamykanie formularza
def handle_event("open_strategy_form", _params, socket) do
  {:noreply, assign(socket, :show_strategy_form, true)}
end

def handle_event("close_strategy_form", _params, socket) do
  {:noreply, assign(socket, :show_strategy_form, false)}
end

# Przełączanie tabów
def handle_event("switch_strategy_tab", %{"tab" => tab}, socket) do
  {:noreply, assign(socket, :strategy_form_tab, String.to_existing_atom(tab))}
end

# Zaznaczanie strategii do miksu
def handle_event("toggle_strategy_select", %{"id" => id}, socket) do
  selected = socket.assigns.selected_strategies
  
  new_selected =
    if id in selected do
      List.delete(selected, id)
    else
      [id | selected]
    end
  
  {:noreply, assign(socket, :selected_strategies, new_selected)}
end

# Usuwanie strategii
def handle_event("delete_strategy", %{"id" => id}, socket) do
  user = socket.assigns.current_user
  
  case Strategies.delete_strategy(user, id) do
    {:ok, _} ->
      {:noreply,
       socket
       |> put_flash(:info, "Strategia została usunięta")
       |> load_strategies()}
    
    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Nie udało się usunąć strategii: #{reason}")}
  end
end
```

**Custom hooki**: Nie wymagane

## 7. Integracja API

### Strategies.list_strategies/2

**Request**:
```elixir
Strategies.list_strategies(user, opts \\ [])
# opts: [sort: "performance_score", order: "asc", limit: 100]
```

**Response**:
```elixir
[
  %Strategy{
    id: "uuid",
    name: "Hot Numbers Focus",
    type: :manual,
    performance_score: 125430.5,
    description: "Focuses on frequently drawn numbers",
    rules: %{...},
    ...
  },
  ...
]
```

**Implementacja backend**:
```elixir
def list_strategies(user, opts \\ []) do
  query = from s in Strategy,
    where: s.user_id == ^user.id and s.status == :active
  
  query = apply_sort(query, opts[:sort], opts[:order])
  
  query
  |> limit(^(opts[:limit] || 100))
  |> Repo.all()
end

defp apply_sort(query, "performance_score", "asc") do
  from s in query,
    order_by: [asc_nulls_last: s.performance_score]
end
# ... inne warianty sortowania
```

### Strategies.create_manual_strategy/2

**Request**:
```elixir
Strategies.create_manual_strategy(user, attrs)
# attrs: %{name, description, rules}
```

**Response**:
```elixir
{:ok, %Strategy{}} | {:error, %Ecto.Changeset{}}
```

**Implementacja**:
```elixir
def create_manual_strategy(user, attrs) do
  %Strategy{}
  |> Strategy.changeset(Map.merge(attrs, %{
    type: :manual,
    user_id: user.id,
    status: :active
  }))
  |> Repo.insert()
end
```

### Strategies.create_ai_strategy/2

**Request**:
```elixir
Strategies.create_ai_strategy(user, %{prompt: "..."})
```

**Response**:
```elixir
{:ok, %Strategy{}} | {:error, reason}
```

**Implementacja**:
```elixir
def create_ai_strategy(user, %{prompt: prompt}) do
  # 1. Sprawdź rate limit
  if rate_limit_exceeded?(user) do
    {:error, :rate_limit_exceeded}
  else
    # 2. Pobierz dane historyczne
    historical_data = get_historical_data_for_ai()
    
    # 3. Wywołaj AI API
    case AIProvider.generate_strategy(prompt, historical_data) do
      {:ok, ai_response} ->
        # 4. Waliduj i zapisz
        attrs = %{
          name: ai_response["strategy_name"],
          description: ai_response["description"],
          rules: ai_response["rules"],
          ai_prompt: prompt,
          type: :ai_generated,
          user_id: user.id
        }
        
        %Strategy{}
        |> Strategy.changeset(attrs)
        |> Repo.insert()
      
      {:error, reason} ->
        {:error, reason}
    end
  end
end

defp rate_limit_exceeded?(user) do
  today = Date.utc_today()
  count = Repo.aggregate(
    from(s in Strategy,
      where: s.user_id == ^user.id and
             s.type == :ai_generated and
             fragment("DATE(?)", s.inserted_at) == ^today
    ),
    :count
  )
  
  count >= 5  # max 5 AI generations per day
end
```

### Strategies.delete_strategy/2

**Request**:
```elixir
Strategies.delete_strategy(user, strategy_id)
```

**Response**:
```elixir
{:ok, %Strategy{}} | {:error, :not_found | :unauthorized}
```

**Implementacja**:
```elixir
def delete_strategy(user, strategy_id) do
  case Repo.get_by(Strategy, id: strategy_id, user_id: user.id) do
    nil ->
      {:error, :not_found}
    
    strategy ->
      # Soft delete
      strategy
      |> Strategy.changeset(%{status: :deleted})
      |> Repo.update()
  end
end
```

## 8. Interakcje użytkownika

### Tworzenie nowej strategii (manualna)

**Krok 1**: Kliknięcie "Nowa strategia"
- Event: `phx-click="open_strategy_form"`
- Rezultat: `assign(:show_strategy_form, true)` → modal się otwiera

**Krok 2**: Wybór tabu "Manualna"
- Event: `phx-click="switch_strategy_tab"` z `phx-value-tab="manual"`
- Rezultat: `assign(:strategy_form_tab, :manual)` → wyświetlenie formularza manualnego

**Krok 3**: Wypełnienie formularza
- Wprowadzenie nazwy, ratio, wag, preferowanych liczb
- Event: `phx-change="validate_strategy"` - walidacja w czasie rzeczywistym
- Rezultat: Wyświetlanie błędów walidacji inline

**Krok 4**: Zapisanie strategii
- Event: `phx-submit="create_manual_strategy"`
- Handler wywołuje: `Strategies.create_manual_strategy(user, attrs)`
- Rezultat: 
  - Sukces: Flash "Strategia utworzona", zamknięcie modala, odświeżenie listy
  - Błąd: Wyświetlenie błędów walidacji

### Tworzenie strategii przez AI

**Krok 1**: Wybór tabu "AI"
- Przełączenie na formularz AI

**Krok 2**: Wprowadzenie promptu
- Textarea z limitem 500 znaków
- Podpowiedzi z przykładami promptów

**Krok 3**: Generowanie
- Event: `phx-click="generate_ai_strategy"`
- Wyświetlenie loadera ("Generuję strategię...")
- Handler wywołuje: `Strategies.create_ai_strategy(user, %{prompt: prompt})`
- Rezultat:
  - Sukces: Wyświetlenie wygenerowanej strategii, opcja zapisu
  - Błąd: Alert z komunikatem, przycisk "Spróbuj ponownie"

### Usuwanie strategii

**Krok 1**: Kliknięcie "Usuń"
- Event: `phx-click="delete_strategy"` z `data-confirm`
- Przeglądarkawyświetla natywny dialog potwierdzenia

**Krok 2**: Potwierdzenie
- Handler wywołuje: `Strategies.delete_strategy(user, id)`
- Rezultat:
  - Sukces: Flash "Strategia usunięta", odświeżenie listy
  - Błąd: Flash z komunikatem błędu

### Miksowanie strategii

**Krok 1**: Zaznaczenie 2-3 strategii
- Event: `phx-click="toggle_strategy_select"` na checkboxach
- Rezultat: Aktualizacja `@selected_strategies`, aktywacja przycisku "Utwórz mix"

**Krok 2**: Kliknięcie "Utwórz mix"
- Event: `phx-click="create_mix"` (TODO)
- Otwarcie modala z opcjami miksu
- AI generuje hybrydową strategię

## 9. Warunki i walidacja

### Walidacja formularza manualnego

**Sprawdzane w**: `Strategy.changeset/2`

**Reguły**:
1. **Nazwa**: 
   - Wymagana, max 255 znaków
   - Unikalność nie wymagana (user może mieć strategie o tej samej nazwie)

2. **Ratio main even/odd**:
   ```elixir
   validate_change(:rules, fn :rules, rules ->
     ratio = get_in(rules, ["main_numbers", "ratio_even_odd"])
     if Enum.sum(ratio) != 5 do
       [rules: "Ratio parzyste/nieparzyste musi sumować się do 5"]
     else
       []
     end
   end)
   ```

3. **Ratio main low/high**:
   - Suma musi być 5

4. **Weights main**:
   ```elixir
   weights = get_in(rules, ["main_numbers", "weights"])
   sum = Enum.sum(Map.values(weights))
   if abs(sum - 1.0) > 0.001 do
     [rules: "Wagi muszą sumować się do 1.0"]
   end
   ```

5. **Preferowane liczby**:
   - Główne: zakres 1-50
   - Euro: zakres 1-12

**Wpływ na UI**:
- Błędy wyświetlane inline pod polami
- Przycisk "Zapisz" disabled gdy formularz nieprawidłowy
- Kolorowanie pól z błędami (czerwona ramka)

### Rate limiting dla AI

**Sprawdzane w**: `Strategies.create_ai_strategy/2`

**Warunek**:
```elixir
count_today >= 5
```

**Wpływ na UI**:
- Alert error: "Przekroczono limit generacji AI (5/dzień). Spróbuj jutro lub utwórz strategię manualnie."
- Przycisk "Generuj" disabled po osiągnięciu limitu
- Licznik pokazujący pozostałe generacje (np. "3/5 pozostałe")

### Aktywacja przycisku "Utwórz mix"

**Sprawdzane w**: Template `strategies_section`

**Warunek**:
```elixir
length(@selected_strategies) >= 2 && length(@selected_strategies) <= 3
```

**Wpływ na UI**:
- Przycisk disabled gdy < 2 lub > 3 zaznaczone
- Wyświetlenie liczby zaznaczonych w tekście przycisku: "Utwórz mix (2)"

## 10. Obsługa błędów

### Błąd walidacji strategii manualnej

**Scenariusz**: Nieprawidłowe dane w formularzu (np. wagi sumują się do 0.9)

**Obsługa**:
```elixir
def handle_event("create_manual_strategy", %{"strategy" => attrs}, socket) do
  user = socket.assigns.current_user
  
  case Strategies.create_manual_strategy(user, attrs) do
    {:ok, strategy} ->
      {:noreply,
       socket
       |> put_flash(:info, "Strategia została utworzona")
       |> assign(:show_strategy_form, false)
       |> load_strategies()}
    
    {:error, %Ecto.Changeset{} = changeset} ->
      {:noreply, assign(socket, :strategy_form, to_form(changeset))}
  end
end
```

**UI**: Błędy wyświetlane inline, formularz pozostaje otwarty

### Błąd AI - timeout

**Scenariusz**: AI API nie odpowiada w ciągu 30s

**Obsługa**:
```elixir
case AIProvider.generate_strategy(prompt, data, timeout: 30_000) do
  {:error, :timeout} ->
    {:noreply,
     socket
     |> put_flash(:error, "AI service timeout. Spróbuj ponownie lub użyj prostszego promptu.")
     |> assign(:ai_loading, false)}
end
```

**UI**: Alert error, przycisk "Spróbuj ponownie", sugestia uproszczenia promptu

### Błąd AI - invalid JSON

**Scenariusz**: AI zwraca nieprawidłowy JSON lub brakujące pola

**Obsługa**:
```elixir
case Jason.decode(ai_response_body) do
  {:ok, data} ->
    if validate_ai_response_structure(data) do
      create_strategy_from_ai_data(data)
    else
      {:error, :invalid_structure}
    end
  
  {:error, _} ->
    {:error, :invalid_json}
end
```

**UI**: Alert error: "AI zwróciło nieprawidłowe dane. Spróbuj ponownie lub zgłoś problem."

### Błąd AI - rate limit exceeded

**Scenariusz**: Użytkownik próbuje wygenerować 6. strategię dzisiaj

**Obsługa**:
```elixir
if rate_limit_exceeded?(user) do
  {:noreply,
   socket
   |> put_flash(:error, "Przekroczono limit generacji AI (5/dzień). Spróbuj jutro.")
   |> assign(:ai_disabled, true)}
end
```

**UI**: 
- Alert error z informacją o limicie
- Przycisk "Generuj" disabled
- Sugestia utworzenia strategii manualnej

### Błąd usuwania strategii z symulacjami

**Scenariusz**: Strategia ma powiązane symulacje

**Obsługa** (soft delete):
```elixir
def delete_strategy(user, strategy_id) do
  strategy = Repo.get_by!(Strategy, id: strategy_id, user_id: user.id)
  
  # Soft delete - zachowujemy dane dla integralności symulacji
  strategy
  |> change(%{status: :deleted})
  |> Repo.update()
end
```

**UI**: 
- Strategia znika z listy
- Symulacje zachowują link do strategii
- Opcja "Odzyskaj" (TODO w zaawansowanej wersji)

## 11. Kroki implementacji

### Krok 1: Struktura podstawowa

1.1. Utworzyć plik `lib/numbers_evolution_web/components/sections_components.ex`

1.2. Zdefiniować komponent `strategies_section/1`:
```elixir
attr :strategies, :list, required: true
attr :selected_strategies, :list, required: true
attr :show_strategy_form, :boolean, required: true
attr :strategy_form_tab, :atom, required: true

def strategies_section(assigns) do
  # Template
end
```

### Krok 2: Implementacja listy strategii

2.1. Dodać nagłówek z przyciskami:
```heex
<div class="flex justify-between items-center">
  <h1 class="text-4xl font-bold">Moje Strategie</h1>
  <div class="flex gap-4">
    <button
      :if={length(@selected_strategies) >= 2}
      phx-click="create_mix"
      class="btn btn-secondary"
    >
      <.icon name="hero-beaker" /> Utwórz mix ({length(@selected_strategies)})
    </button>
    <button phx-click="open_strategy_form" class="btn btn-primary">
      <.icon name="hero-plus" /> Nowa strategia
    </button>
  </div>
</div>
```

2.2. Dodać empty state:
```heex
<%= if @strategies == [] do %>
  <.empty_state icon="hero-light-bulb">
    <:title>Nie masz jeszcze strategii</:title>
    <:description>Utwórz swoją pierwszą strategię manualnie lub wygeneruj przez AI</:description>
    <:action>
      <button phx-click="open_strategy_form" class="btn btn-primary btn-lg">
        Utwórz pierwszą strategię
      </button>
    </:action>
  </.empty_state>
<% end %>
```

2.3. Dodać grid kart strategii:
```heex
<div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
  <%= for strategy <- @strategies do %>
    <.strategy_card strategy={strategy} selected={strategy.id in @selected_strategies} />
  <% end %>
</div>
```

### Krok 3: Implementacja strategy_card

3.1. Utworzyć subkomponent:
```elixir
attr :strategy, :map, required: true
attr :selected, :boolean, required: true

defp strategy_card(assigns) do
  ~H"""
  <.card>
    <div class="flex items-start gap-3">
      <input
        type="checkbox"
        phx-click="toggle_strategy_select"
        phx-value-id={@strategy.id}
        checked={@selected}
        class="checkbox checkbox-primary mt-1"
      />
      <div class="flex-1">
        <div class="flex items-center gap-2 mb-2">
          <h3 class="font-bold text-lg">{@strategy.name}</h3>
          <.badge variant={if @strategy.type == :ai_generated, do: "success", else: "info"} size="sm">
            {if @strategy.type == :ai_generated, do: "AI", else: "Manual"}
          </.badge>
        </div>
        
        <p :if={@strategy.description} class="text-sm text-base-content/70 mb-4">
          {@strategy.description}
        </p>
        
        <div class="stats stats-horizontal shadow w-full mb-4">
          <div class="stat p-3">
            <div class="stat-title text-xs">Performance</div>
            <div class="stat-value text-base">
              {if @strategy.performance_score, do: Float.round(@strategy.performance_score, 2), else: "—"}
            </div>
          </div>
        </div>
        
        <div class="flex gap-2 flex-wrap">
          <button phx-click="view_strategy_details" phx-value-id={@strategy.id} class="btn btn-sm btn-ghost">
            <.icon name="hero-eye" class="size-4" /> Szczegóły
          </button>
          <button
            phx-click="delete_strategy"
            phx-value-id={@strategy.id}
            data-confirm="Czy na pewno usunąć tę strategię?"
            class="btn btn-sm btn-error"
          >
            <.icon name="hero-trash" class="size-4" /> Usuń
          </button>
        </div>
      </div>
    </div>
  </.card>
  """
end
```

### Krok 4: Implementacja modala formularza

4.1. Dodać modal z tabami:
```heex
<.modal
  id="strategy-form-modal"
  show={@show_strategy_form}
  on_cancel={JS.push("close_strategy_form")}
>
  <:title>Nowa Strategia</:title>
  
  <div class="tabs tabs-boxed mb-4">
    <button
      phx-click="switch_strategy_tab"
      phx-value-tab="manual"
      class={["tab", @strategy_form_tab == :manual && "tab-active"]}
    >
      Manualna
    </button>
    <button
      phx-click="switch_strategy_tab"
      phx-value-tab="ai"
      class={["tab", @strategy_form_tab == :ai && "tab-active"]}
    >
      AI
    </button>
  </div>
  
  <%= if @strategy_form_tab == :manual do %>
    <.manual_strategy_form form={@manual_form} />
  <% else %>
    <.ai_strategy_form 
      form={@ai_form} 
      ai_loading={@ai_loading} 
      generated_strategy={@generated_strategy}
    />
  <% end %>
  
  <:actions>
    <button phx-click="close_strategy_form" class="btn">Zamknij</button>
    <%= if @strategy_form_tab == :manual do %>
      <button phx-click="save_manual_strategy" class="btn btn-primary">Zapisz strategię</button>
    <% else %>
      <%= if @generated_strategy do %>
        <button phx-click="save_ai_strategy" class="btn btn-primary">Zapisz strategię</button>
      <% else %>
        <button phx-click="generate_ai_strategy" class="btn btn-primary" disabled={@ai_loading}>
          <%= if @ai_loading do %>
            <span class="loading loading-spinner loading-sm"></span> Generuję...
          <% else %>
            <.icon name="hero-sparkles" class="size-5" /> Generuj strategię
          <% end %>
        </button>
      <% end %>
    <% end %>
  </:actions>
</.modal>
```

### Krok 4.2: Implementacja formularza manualnego

4.2.1. Dodać subkomponent `manual_strategy_form/1`:
```elixir
attr :form, :map, required: true

defp manual_strategy_form(assigns) do
  ~H"""
  <.form
    for={@form}
    id="manual-strategy-form"
    phx-change="validate_manual_strategy"
    phx-submit="save_manual_strategy"
    class="space-y-6"
  >
    <%!-- Podstawowe informacje --%>
    <div class="space-y-4">
      <h3 class="font-semibold text-lg">Informacje podstawowe</h3>
      
      <.input field={@form[:name]} type="text" label="Nazwa strategii" required />
      <.input field={@form[:description]} type="textarea" label="Opis (opcjonalny)" />
    </div>
    
    <%!-- Blacklist liczb --%>
    <div class="space-y-4">
      <h3 class="font-semibold text-lg">Blacklist liczb (pomijane)</h3>
      <.alert kind="info" class="text-sm">
        Liczby z blacklist będą całkowicie pomijane przy generowaniu.
      </.alert>
      
      <.input
        field={@form[:blacklist_main]}
        type="text"
        label="Główne (1-50)"
        placeholder="np. 13, 26, 39"
        class="input-sm"
      />
      <span class="text-xs text-base-content/70">
        Oddziel przecinkami. Max 25 liczb (musi zostać min. 5 do wyboru)
      </span>
      
      <.input
        field={@form[:blacklist_euro]}
        type="text"
        label="Euro (1-12)"
        placeholder="np. 13"
        class="input-sm"
      />
      <span class="text-xs text-base-content/70">
        Oddziel przecinkami. Max 6 liczb (musi zostać min. 2 do wyboru)
      </span>
    </div>
    
    <%!-- Ratio parzyste/nieparzyste --%>
    <div class="space-y-4">
      <h3 class="font-semibold text-lg">Ratio parzyste/nieparzyste</h3>
      
      <div class="grid grid-cols-2 gap-4">
        <.input
          field={@form[:main_even]}
          type="number"
          label="Główne parzyste"
          min="0"
          max="5"
          required
        />
        <.input
          field={@form[:main_odd]}
          type="number"
          label="Główne nieparzyste"
          min="0"
          max="5"
          required
        />
      </div>
      <span class="text-xs text-base-content/70">Suma musi być 5</span>
      
      <div class="grid grid-cols-2 gap-4">
        <.input
          field={@form[:euro_even]}
          type="number"
          label="Euro parzyste"
          min="0"
          max="2"
          required
        />
        <.input
          field={@form[:euro_odd]}
          type="number"
          label="Euro nieparzyste"
          min="0"
          max="2"
          required
        />
      </div>
      <span class="text-xs text-base-content/70">Suma musi być 2</span>
    </div>
    
    <%!-- Ratio low/high --%>
    <div class="space-y-4">
      <h3 class="font-semibold text-lg">Ratio niskie/wysokie (główne)</h3>
      
      <div class="grid grid-cols-2 gap-4">
        <.input
          field={@form[:main_low]}
          type="number"
          label="Niskie (1-25)"
          min="0"
          max="5"
          required
        />
        <.input
          field={@form[:main_high]}
          type="number"
          label="Wysokie (26-50)"
          min="0"
          max="5"
          required
        />
      </div>
      <span class="text-xs text-base-content/70">Suma musi być 5</span>
    </div>
    
    <%!-- Wagi --%>
    <div class="space-y-4">
      <h3 class="font-semibold text-lg">Wagi źródeł liczb (główne)</h3>
      <.alert kind="info" class="text-sm">
        Wagi określają skąd czerpać liczby: hot (często wypadające), cold (rzadko wypadające), random (losowe).
      </.alert>
      
      <div class="space-y-3">
        <div>
          <label class="label">
            <span class="label-text">Hot (często wypadające): {@form[:weight_hot].value || 0.4}</span>
          </label>
          <input
            type="range"
            name="strategy[weight_hot]"
            min="0"
            max="1"
            step="0.1"
            value={@form[:weight_hot].value || 0.4}
            class="range range-primary range-sm"
          />
        </div>
        
        <div>
          <label class="label">
            <span class="label-text">Cold (rzadko wypadające): {@form[:weight_cold].value || 0.2}</span>
          </label>
          <input
            type="range"
            name="strategy[weight_cold]"
            min="0"
            max="1"
            step="0.1"
            value={@form[:weight_cold].value || 0.2}
            class="range range-primary range-sm"
          />
        </div>
        
        <div>
          <label class="label">
            <span class="label-text">Random (losowe): {@form[:weight_random].value || 0.4}</span>
          </label>
          <input
            type="range"
            name="strategy[weight_random]"
            min="0"
            max="1"
            step="0.1"
            value={@form[:weight_random].value || 0.4}
            class="range range-primary range-sm"
          />
        </div>
      </div>
      <span class="text-xs text-base-content/70">Suma musi być 1.0</span>
    </div>
    
    <%!-- Preferowane liczby --%>
    <div class="space-y-4">
      <h3 class="font-semibold text-lg">Preferowane liczby (opcjonalne)</h3>
      
      <.input
        field={@form[:preferred_hot]}
        type="text"
        label="Hot numbers główne"
        placeholder="np. 7, 23, 34"
      />
      <span class="text-xs text-base-content/70">Max 10 liczb, oddziel przecinkami</span>
      
      <.input
        field={@form[:preferred_cold]}
        type="text"
        label="Cold numbers główne"
        placeholder="np. 1, 50"
      />
      <span class="text-xs text-base-content/70">Max 10 liczb, oddziel przecinkami</span>
      
      <.input
        field={@form[:preferred_euro]}
        type="text"
        label="Preferowane euro"
        placeholder="np. 3, 9"
      />
      <span class="text-xs text-base-content/70">Max 6 liczb, oddziel przecinkami</span>
    </div>
    
    <%!-- Ograniczenia dystrybucji --%>
    <div class="space-y-4">
      <h3 class="font-semibold text-lg">Ograniczenia dystrybucji (opcjonalne)</h3>
      
      <.input
        field={@form[:max_per_decade]}
        type="number"
        label="Max liczb w jednej dziesiątce"
        placeholder="2"
        min="1"
        max="5"
      />
      <span class="text-xs text-base-content/70">
        Dziesiątki: 1-10, 11-20, 21-30, 31-40, 41-50
      </span>
      
      <.input
        field={@form[:max_consecutive]}
        type="number"
        label="Max kolejnych liczb"
        placeholder="2"
        min="1"
        max="4"
      />
      <span class="text-xs text-base-content/70">
        Np. max 2 = może być 7,8 ale nie 7,8,9
      </span>
    </div>
  </.form>
  """
end
```

### Krok 4.3: Implementacja formularza AI

4.3.1. Dodać subkomponent `ai_strategy_form/1`:
```elixir
attr :form, :map, required: true
attr :ai_loading, :boolean, default: false
attr :generated_strategy, :map, default: nil

defp ai_strategy_form(assigns) do
  ~H"""
  <div class="space-y-6">
    <%= if @generated_strategy do %>
      <%!-- Preview wygenerowanej strategii --%>
      <.alert kind="success">
        <strong>Strategia wygenerowana pomyślnie!</strong>
      </.alert>
      
      <div class="card bg-base-200">
        <div class="card-body">
          <h3 class="card-title">{@generated_strategy["strategy_name"]}</h3>
          <p class="text-sm">{@generated_strategy["description"]}</p>
          
          <div class="divider">Reguły</div>
          
          <div class="text-sm space-y-2">
            <p><strong>Main numbers:</strong></p>
            <ul class="list-disc list-inside ml-4">
              <li>Ratio even/odd: {inspect(@generated_strategy["rules"]["main_numbers"]["ratio_even_odd"])}</li>
              <li>Ratio low/high: {inspect(@generated_strategy["rules"]["main_numbers"]["ratio_low_high"])}</li>
              <li>Wagi: {inspect(@generated_strategy["rules"]["main_numbers"]["weights"])}</li>
            </ul>
            
            <p><strong>Euro numbers:</strong></p>
            <ul class="list-disc list-inside ml-4">
              <li>Ratio even/odd: {inspect(@generated_strategy["rules"]["euro_numbers"]["ratio_even_odd"])}</li>
              <li>Wagi: {inspect(@generated_strategy["rules"]["euro_numbers"]["weights"])}</li>
            </ul>
          </div>
          
          <div class="divider">Uzasadnienie AI</div>
          <p class="text-sm">{@generated_strategy["reasoning"]}</p>
        </div>
      </div>
      
      <.alert kind="info" class="text-sm">
        Możesz zapisać tę strategię lub wygenerować nową.
      </.alert>
      
    <% else %>
      <%!-- Formularz promptu --%>
      <.form for={@form} id="ai-strategy-form" class="space-y-4">
        <.input
          field={@form[:prompt]}
          type="textarea"
          label="Opisz strategię dla AI"
          placeholder="Np. Strategia koncentrująca się na ostatnich hot numbers z ostatnich 32 losowań..."
          rows="4"
          maxlength="500"
          required
        />
        <span class="text-xs text-base-content/70">
          Min 10, max 500 znaków. Pozostało: {500 - String.length(@form[:prompt].value || "")}
        </span>
        
        <div class="divider">Przykładowe prompty</div>
        
        <div class="space-y-2">
          <button
            type="button"
            phx-click="use_example_prompt"
            phx-value-prompt="Pomin połowę liczb od 1 do 50 (wszystkie parzyste). Skupimy się tylko na nieparzystych. Dla euro wszystkie liczby dostępne."
            class="btn btn-sm btn-outline w-full text-left justify-start"
          >
            <.icon name="hero-light-bulb" class="size-4" />
            Pomin połowę liczb (tylko nieparzyste)
          </button>
          
          <button
            type="button"
            phx-click="use_example_prompt"
            phx-value-prompt="Dwie liczby główne mają być nieparzyste, reszta parzyste. Wagi: 50% hot, 30% random, 20% cold."
            class="btn btn-sm btn-outline w-full text-left justify-start"
          >
            <.icon name="hero-light-bulb" class="size-4" />
            2 nieparzyste, 3 parzyste
          </button>
          
          <button
            type="button"
            phx-click="use_example_prompt"
            phx-value-prompt="Maksymalnie 2 liczby w jednej dziesiątce i nie mogą być kolejne (np. 7,8). Preferuj hot numbers z ostatnich 16 losowań."
            class="btn btn-sm btn-outline w-full text-left justify-start"
          >
            <.icon name="hero-light-bulb" class="size-4" />
            Max 2 w dziesiątce, bez kolejnych
          </button>
          
          <button
            type="button"
            phx-click="use_example_prompt"
            phx-value-prompt="Strategia balansująca hot i cold numbers z wagami 40% hot, 40% random, 20% cold. Ratio 3 parzyste/2 nieparzyste."
            class="btn btn-sm btn-outline w-full text-left justify-start"
          >
            <.icon name="hero-light-bulb" class="size-4" />
            Balans hot/cold
          </button>
        </div>
        
        <.alert kind="warning" class="text-sm">
          Limit: 5 generacji AI dziennie. Pozostało: {5 - (@form[:used_today].value || 0)}
        </.alert>
      </.form>
    <% end %>
  </div>
  """
end
```

### Krok 5: Implementacja event handlers w PageLive

5.1. Dodać handlery dla strategii:
```elixir
# W PageLive
def handle_event("open_strategy_form", _params, socket) do
  {:noreply, assign(socket, :show_strategy_form, true)}
end

def handle_event("close_strategy_form", _params, socket) do
  {:noreply, assign(socket, :show_strategy_form, false)}
end

def handle_event("switch_strategy_tab", %{"tab" => tab}, socket) do
  {:noreply, assign(socket, :strategy_form_tab, String.to_existing_atom(tab))}
end

def handle_event("toggle_strategy_select", %{"id" => id}, socket) do
  selected = socket.assigns.selected_strategies
  
  new_selected =
    if id in selected do
      List.delete(selected, id)
    else
      [id | selected]
    end
  
  {:noreply, assign(socket, :selected_strategies, new_selected)}
end

def handle_event("delete_strategy", %{"id" => id}, socket) do
  user = socket.assigns.current_user
  
  case Strategies.delete_strategy(user, id) do
    {:ok, _} ->
      {:noreply,
       socket
       |> put_flash(:info, "Strategia została usunięta")
       |> load_strategies()}
    
    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Nie udało się usunąć strategii: #{inspect(reason)}")}
  end
end
```

### Krok 6: Implementacja backend - Strategies context

6.1. Utworzyć context `lib/numbers_evolution/strategies.ex`:
```elixir
defmodule NumbersEvolution.Strategies do
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Strategies.Strategy
  import Ecto.Query

  def list_strategies(user, opts \\ []) do
    query = from s in Strategy,
      where: s.user_id == ^user.id and s.status == :active
    
    query = apply_sort(query, opts)
    
    Repo.all(query)
  end
  
  def create_manual_strategy(user, attrs) do
    %Strategy{}
    |> Strategy.changeset(Map.merge(attrs, %{
      type: :manual,
      user_id: user.id,
      status: :active
    }))
    |> Repo.insert()
  end
  
  def delete_strategy(user, strategy_id) do
    case Repo.get_by(Strategy, id: strategy_id, user_id: user.id) do
      nil -> {:error, :not_found}
      strategy ->
        strategy
        |> Ecto.Changeset.change(%{status: :deleted})
        |> Repo.update()
    end
  end
  
  defp apply_sort(query, opts) do
    case {opts[:sort], opts[:order]} do
      {"performance_score", "asc"} ->
        from s in query, order_by: [asc_nulls_last: s.performance_score]
      {"performance_score", "desc"} ->
        from s in query, order_by: [desc_nulls_last: s.performance_score]
      _ ->
        from s in query, order_by: [desc: s.inserted_at]
    end
  end
end
```

### Krok 7: Implementacja schematu Strategy

7.1. Utworzyć schema `lib/numbers_evolution/strategies/strategy.ex`:
```elixir
defmodule NumbersEvolution.Strategies.Strategy do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "strategies" do
    field :name, :string
    field :type, Ecto.Enum, values: [:manual, :ai_generated]
    field :status, Ecto.Enum, values: [:active, :archived, :deleted], default: :active
    field :description, :string
    field :rules, :map
    field :performance_score, :float
    field :ai_prompt, :string
    
    belongs_to :user, NumbersEvolution.Accounts.User
    has_many :simulations, NumbersEvolution.Simulations.Simulation
    
    timestamps(type: :utc_datetime)
  end
  
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:name, :type, :description, :rules, :ai_prompt, :user_id, :status])
    |> validate_required([:name, :type, :rules, :user_id])
    |> validate_length(:name, max: 255)
    |> validate_length(:ai_prompt, max: 500)
    |> validate_rules()
  end
  
  defp validate_rules(changeset) do
    case get_change(changeset, :rules) do
      nil -> changeset
      rules -> validate_rules_structure(changeset, rules)
    end
  end
  
  defp validate_rules_structure(changeset, rules) do
    # Walidacja struktury rules
    # TODO: Implementacja szczegółowej walidacji
    changeset
  end
end
```

### Krok 8: Migracja bazy danych

8.1. Utworzyć migrację:
```bash
mix ecto.gen.migration create_strategies
```

8.2. W migracji:
```elixir
def change do
  create table(:strategies, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :name, :string, null: false
    add :type, :string, null: false  # manual, ai_generated
    add :status, :string, default: "active"  # active, archived, deleted
    add :description, :text
    add :rules, :map, null: false  # JSONB
    add :performance_score, :float
    add :ai_prompt, :text
    add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
    
    timestamps(type: :utc_datetime)
  end
  
  create index(:strategies, [:user_id])
  create index(:strategies, [:status])
  create index(:strategies, [:performance_score])
  create index(:strategies, [:type])
end
```

### Krok 9: Testowanie

9.1. Testy jednostkowe context:
```elixir
# test/numbers_evolution/strategies_test.exs
defmodule NumbersEvolution.StrategiesTest do
  use NumbersEvolution.DataCase
  
  alias NumbersEvolution.Strategies
  
  describe "list_strategies/2" do
    test "returns only user's active strategies" do
      user = insert(:user)
      strategy1 = insert(:strategy, user: user, status: :active)
      strategy2 = insert(:strategy, user: user, status: :deleted)
      other_user_strategy = insert(:strategy, status: :active)
      
      strategies = Strategies.list_strategies(user)
      
      assert length(strategies) == 1
      assert hd(strategies).id == strategy1.id
    end
  end
  
  describe "create_manual_strategy/2" do
    test "creates strategy with valid attrs" do
      user = insert(:user)
      attrs = %{
        name: "Test Strategy",
        rules: valid_rules()
      }
      
      assert {:ok, strategy} = Strategies.create_manual_strategy(user, attrs)
      assert strategy.name == "Test Strategy"
      assert strategy.type == :manual
      assert strategy.user_id == user.id
    end
    
    test "returns error with invalid rules" do
      user = insert(:user)
      attrs = %{name: "Test", rules: %{}}
      
      assert {:error, changeset} = Strategies.create_manual_strategy(user, attrs)
      assert "invalid rules" in errors_on(changeset).rules
    end
  end
end
```

9.2. Testy LiveView:
```elixir
# test/numbers_evolution_web/live/page_live_test.exs
test "displays strategies and allows selection", %{conn: conn, user: user} do
  strategy1 = insert(:strategy, user: user, name: "Strategy 1")
  strategy2 = insert(:strategy, user: user, name: "Strategy 2")
  
  {:ok, view, _html} = live(conn, "/")
  
  # Nawiguj do strategii
  view |> element("button", "Strategie") |> render_click()
  
  assert render(view) =~ "Strategy 1"
  assert render(view) =~ "Strategy 2"
  
  # Zaznacz strategie
  view |> element("input[type=checkbox][phx-value-id='#{strategy1.id}']") |> render_click()
  view |> element("input[type=checkbox][phx-value-id='#{strategy2.id}']") |> render_click()
  
  assert has_element?(view, "button", ~r/Utwórz mix \(2\)/)
end

test "opens and closes strategy form modal", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/")
  
  view |> element("button", "Strategie") |> render_click()
  
  refute has_element?(view, "#strategy-form-modal.modal-open")
  
  view |> element("button", "Nowa strategia") |> render_click()
  
  assert has_element?(view, "#strategy-form-modal.modal-open")
  
  view |> element("button", "Zamknij") |> render_click()
  
  refute has_element?(view, "#strategy-form-modal.modal-open")
end
```

### Krok 10: Integracja AI (opcjonalna - może być w kolejnym etapie)

10.1. Utworzyć moduł `lib/numbers_evolution/ai_provider.ex`:
```elixir
defmodule NumbersEvolution.AIProvider do
  @callback generate_strategy(prompt :: String.t(), context :: map()) ::
    {:ok, map()} | {:error, atom()}
  
  def generate_strategy(prompt, context) do
    provider().generate_strategy(prompt, context)
  end
  
  defp provider do
    Application.get_env(:numbers_evolution, :ai_provider, NumbersEvolution.AIProvider.Claude)
  end
end
```

10.2. Implementacja dla Claude:
```elixir
defmodule NumbersEvolution.AIProvider.Claude do
  @behaviour NumbersEvolution.AIProvider
  
  def generate_strategy(prompt, context) do
    # Implementacja wywołania Claude API
    # TODO
  end
end
```

---

**Status implementacji**: ✅ Podstawowa struktura zaimplementowana, formularze TODO
**Priorytet dla MVP**: WYSOKI (kluczowa funkcjonalność)
**Zależności**: Wymaga działającego `Accounts` context, opcjonalnie AI provider
**Następne kroki**: Implementacja formularzy (manualny i AI), integracja AI API

