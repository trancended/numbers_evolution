# Plan implementacji widoku Symulacje

## 1. Przegląd

Sekcja Symulacji umożliwia użytkownikom uruchamianie symulacji strategii na historycznych losowaniach Eurojackpot. Głównym celem jest testowanie skuteczności strategii przez wielokrotne generowanie zestawów liczb i porównywanie ich z target draw do momentu trafienia głównej wygranej (5+2) lub osiągnięcia limitu. Sekcja wyświetla także historię wszystkich przeprowadzonych symulacji z możliwością przeglądania szczegółów.

## 2. Routing widoku

Widok dostępny na głównej ścieżce `/` z parametrem `@active_section = :simulations`.

**Routing**:
- URL: `/`
- LiveView: `NumbersEvolutionWeb.PageLive`
- Komponent: `simulations_section/1` z `NumbersEvolutionWeb.SectionsComponents`
- Dostęp: Wymagana autentykacja

## 3. Struktura komponentów

```
PageLive (LiveView - kontener główny)
└── simulations_section (function component)
    ├── Nagłówek
    ├── Karta formularza uruchomienia symulacji
    │   ├── Alert (gdy brak strategii)
    │   └── simulation_form (subkomponent)
    │       ├── Select strategii
    │       ├── Select target draw
    │       ├── Collapsible opcje zaawansowane
    │       │   ├── Input max_attempts
    │       │   └── Input timeout_seconds
    │       └── Przycisk "Uruchom symulację"
    └── Karta historii symulacji
        ├── Empty state (gdy brak symulacji)
        └── simulations_table (subkomponent)
            └── Wiersze z danymi symulacji
```

## 4. Szczegóły komponentów

### Simulations Section (simulations_section/1)

**Opis komponentu**: Główny kontener sekcji symulacji, zarządzający formularzem uruchamiania i wyświetlaniem historii symulacji.

**Główne elementy HTML i komponenty dzieci**:
- Nagłówek `<h1>`
- Karta formularza (`<.card class="bg-base-200">`)
  - Alert warunkowy przy braku strategii
  - Formularz uruchomienia (`<.simulation_form>`)
- Karta historii (`<.card>`)
  - Empty state lub tabela symulacji

**Obsługiwane zdarzenia**:
- `phx-submit="start_simulation"` - uruchomienie symulacji
- `phx-click="navigate"` z `phx-value-section` - nawigacja do strategii

**Warunki walidacji**:
- Formularz renderowany tylko gdy `@strategies != []`
- Empty state w historii gdy `@simulations == []`

**Typy**:
```elixir
attr :strategies, :list, required: true    # list(Strategy.t())
attr :simulations, :list, required: true   # list(Simulation.t())
attr :draws, :list, required: true         # list(Draw.t())
```

**Propsy**: Jak w typach powyżej

### Simulation Form (simulation_form/1)

**Opis komponentu**: Formularz uruchamiania nowej symulacji z wyborem strategii, target draw i opcjonalnymi limitami.

**Główne elementy HTML**:
- `<form phx-submit="start_simulation">`
- Select dla strategii (`<select name="strategy_id">`)
- Select dla target draw (`<select name="target_draw_id">`)
- Collapsible dla opcji zaawansowanych (`<details class="collapse">`)
  - Input dla max_attempts
  - Input dla timeout_seconds
- Przycisk submit

**Obsługiwane zdarzenia**:
- `phx-submit="start_simulation"` - wysłanie formularza

**Warunki walidacji** (po stronie backendu):
- `strategy_id`: wymagane, musi należeć do użytkownika
- `target_draw_id`: wymagane, musi istnieć
- `max_attempts`: opcjonalne, min 1000, max 10,000,000, default 1,000,000
- `timeout_seconds`: opcjonalne, min 10, max 3600, default 300

**Typy**:
```elixir
attr :strategies, :list, required: true
attr :draws, :list, required: true
```

**Propsy**: Jak w typach powyżej

### Simulations Table (simulations_table/1)

**Opis komponentu**: Tabela wyświetlająca historię symulacji użytkownika z kluczowymi informacjami i linkiem do szczegółów.

**Główne elementy HTML**:
- `<table class="table table-zebra">`
- Nagłówki kolumn
- Wiersze z danymi symulacji
- Komponent statusu (`<.status_indicator>`)
- Przyciski akcji

**Obsługiwane zdarzenia**:
- `phx-click="view_simulation_details"` z `phx-value-id` - otwarcie szczegółów

**Warunki walidacji**: Brak

**Typy**:
```elixir
attr :simulations, :list, required: true   # list(Simulation.t() | preloaded)
```

**Propsy**: Jak w typach powyżej

## 5. Typy

### Simulation (Ecto schema)

```elixir
defmodule NumbersEvolution.Simulations.Simulation do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    id: binary(),
    status: :pending | :running | :success | :timeout | :error,
    attempts_count: non_neg_integer() | nil,
    duration_seconds: float() | nil,
    result: map() | nil,
    options: map(),
    started_at: DateTime.t() | nil,
    completed_at: DateTime.t() | nil,
    user_id: binary(),
    strategy_id: binary(),
    target_draw_id: binary(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "simulations" do
    field :status, Ecto.Enum, values: [:pending, :running, :success, :timeout, :error], default: :pending
    field :attempts_count, :integer
    field :duration_seconds, :float
    field :result, :map  # JSONB
    field :options, :map, default: %{}
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    
    belongs_to :user, NumbersEvolution.Accounts.User
    belongs_to :strategy, NumbersEvolution.Strategies.Strategy
    belongs_to :target_draw, NumbersEvolution.Draws.Draw
    
    timestamps(type: :utc_datetime)
  end
  
  def changeset(simulation, attrs) do
    simulation
    |> cast(attrs, [:status, :attempts_count, :duration_seconds, :result, :options, 
                     :started_at, :completed_at, :user_id, :strategy_id, :target_draw_id])
    |> validate_required([:user_id, :strategy_id, :target_draw_id])
    |> validate_number(:attempts_count, greater_than_or_equal_to: 0)
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:strategy_id)
    |> foreign_key_constraint(:target_draw_id)
  end
end
```

### Draw (Ecto schema)

```elixir
defmodule NumbersEvolution.Draws.Draw do
  use Ecto.Schema

  @type t :: %__MODULE__{
    id: binary(),
    draw_date: Date.t(),
    game_type: String.t(),
    numbers: map(),
    source: String.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "draws" do
    field :draw_date, :date
    field :game_type, :string, default: "eurojackpot"
    field :numbers, :map  # JSONB: %{"main_numbers" => [1,7,23,34,50], "euro_numbers" => [3,9]}
    field :source, :string, default: "manual"
    
    has_many :simulations, NumbersEvolution.Simulations.Simulation, foreign_key: :target_draw_id
    
    timestamps(type: :utc_datetime)
  end
end
```

### SimulationOptions

```elixir
# Struktura options field (JSONB)
%{
  "max_attempts" => 1_000_000,    # integer
  "timeout_seconds" => 300        # integer
}
```

### SimulationResult (success)

```elixir
# Struktura result field (JSONB) dla statusu :success
%{
  "matched_main" => [1, 7, 23, 34, 50],
  "matched_euro" => [3, 9],
  "attempts_count" => 125430,
  "final_draw" => %{
    "main_numbers" => [1, 7, 23, 34, 50],
    "euro_numbers" => [3, 9]
  }
}
```

### SimulationResult (timeout/error)

```elixir
# Struktura result field (JSONB) dla statusu :timeout/:error
%{
  "reason" => "timeout" | "error",
  "limit_reached" => "max_attempts" | "time_limit",
  "attempts_count" => 1000000,
  "error_message" => "..." | nil
}
```

## 6.1 Mechanizm zapobiegania duplikatom prób w symulacji

### Przegląd mechanizmu

W ramach jednej symulacji nie mogą wystąpić duplikaty prób - każda próba generowania zestawu liczb musi być unikalna w obrębie pojedynczej symulacji. Mechanizm skipowania powtórzeń zapewnia, że:

- **Brak duplikatów**: Każda kombinacja liczb występuje maksymalnie raz w pojedynczej symulacji
- **Nie wpływa na licznik**: Pominiete duplikaty nie są liczone jako próby w `attempts_count`
- **Optymalizacja wydajności**: Unikanie redundantnych obliczeń i sprawdzeń trafień

### Architektura mechanizmu

#### Struktura stanu symulacji z kontrolą duplikatów

```elixir
# Rozszerzona struktura SimulationResult z informacjami o duplikatach
%{
  "matched_main" => [1, 7, 23, 34, 50],
  "matched_euro" => [3, 9],
  "attempts_count" => 125430,
  "final_draw" => %{
    "main_numbers" => [1, 7, 23, 34, 50],
    "euro_numbers" => [3, 9]
  },
  "duplicates_skipped" => 0,  # Liczba pominiętych duplikatów (nie wpływa na attempts_count)
  "unique_attempts" => 125430 # attempts_count = total_attempts - duplicates_skipped
}
```

#### Implementacja kontrolera duplikatów

```elixir
defmodule NumbersEvolution.SimulationDuplicateController do
  @moduledoc """
  Kontroler zapobiegający duplikatom prób w pojedynczej symulacji.

  Używa MapSet do efektywnego sprawdzania unikalności kombinacji.
  """

  defstruct [:attempts_set, :duplicates_count]

  @type t :: %__MODULE__{
    attempts_set: MapSet.t(),
    duplicates_count: non_neg_integer()
  }

  @doc """
  Tworzy nowy kontroler duplikatów dla symulacji.
  """
  @spec new() :: t()
  def new() do
    %__MODULE__{
      attempts_set: MapSet.new(),
      duplicates_count: 0
    }
  end

  @doc """
  Sprawdza czy próba jest duplikatem i aktualizuje stan kontrolera.

  Returns:
  - `{:unique, controller}` - próba jest unikalna
  - `{:duplicate, controller}` - próba jest duplikatem, stan zaktualizowany
  """
  @spec check_attempt(t(), %{main: list(), euro: list()}) :: {:unique | :duplicate, t()}
  def check_attempt(%__MODULE__{} = controller, %{main: main, euro: euro}) do
    # Tworzymy hash kombinacji dla efektywnego porównania
    combination_hash = generate_combination_hash(main, euro)

    if MapSet.member?(controller.attempts_set, combination_hash) do
      # Duplikat - zwiększamy licznik i zwracamy :duplicate
      {:duplicate, %__MODULE__{
        controller |
        duplicates_count: controller.duplicates_count + 1
      }}
    else
      # Unikalna próba - dodajemy do zbioru
      {:unique, %__MODULE__{
        controller |
        attempts_set: MapSet.put(controller.attempts_set, combination_hash)
      }}
    end
  end

  @doc """
  Generuje hash kombinacji dla efektywnego porównania.

  Sortuje liczby aby zapewnić deterministyczny hash niezależny od kolejności.
  """
  @spec generate_combination_hash(list(), list()) :: String.t()
  def generate_combination_hash(main_numbers, euro_numbers) do
    # Sortujemy liczby dla deterministycznego hasha
    sorted_main = Enum.sort(main_numbers)
    sorted_euro = Enum.sort(euro_numbers)

    # Tworzymy string reprezentację
    main_str = Enum.join(sorted_main, ",")
    euro_str = Enum.join(sorted_euro, ",")

    # Generujemy hash
    :crypto.hash(:md5, "#{main_str}|#{euro_str}")
    |> Base.encode16(case: :lower)
  end

  @doc """
  Zwraca statystyki duplikatów dla podsumowania symulacji.
  """
  @spec get_stats(t()) :: %{duplicates_skipped: non_neg_integer()}
  def get_stats(%__MODULE__{duplicates_count: count}) do
    %{duplicates_skipped: count}
  end
end
```

### Integracja z główną pętlą symulacji

#### Modyfikacja `simulate_until_match/6`

```elixir
defp simulate_until_match(rules, target, max_attempts, timeout, start_time, controller, current_attempt \\ 0) do
  # Sprawdź limity czasowe i ilościowe
  cond do
    current_attempt >= max_attempts ->
      {:timeout, "max_attempts", current_attempt, controller}

    System.monotonic_time(:second) - start_time >= timeout ->
      {:timeout, "time_limit", current_attempt, controller}

    true ->
      # Wygeneruj liczby
      generated = NumbersEvolution.NumberGenerator.generate_numbers(rules)

      # Sprawdź czy próba jest duplikatem
      case SimulationDuplicateController.check_attempt(controller, generated) do
        {:duplicate, updated_controller} ->
          # Pomijamy duplikat - rekurencyjne wywołanie bez zwiększania licznika prób
          simulate_until_match(rules, target, max_attempts, timeout, start_time, updated_controller, current_attempt)

        {:unique, updated_controller} ->
          # Unikalna próba - sprawdzamy trafienie
          if matches_target?(generated, target) do
            {:success, current_attempt + 1, generated, updated_controller}
          else
            # Kontynuujemy z następną próbą
            simulate_until_match(rules, target, max_attempts, timeout, start_time, updated_controller, current_attempt + 1)
          end
      end
  end
end
```

#### Aktualizacja `run_simulation/3`

```elixir
defp run_simulation(simulation, strategy, target_draw) do
  try do
    # Aktualizuj status na :running
    simulation = Repo.update!(Ecto.Changeset.change(simulation, %{
      status: :running,
      started_at: DateTime.utc_now()
    }))

    # Parametry
    max_attempts = simulation.options["max_attempts"] || 1_000_000
    timeout_seconds = simulation.options["timeout_seconds"] || 300
    start_time = System.monotonic_time(:second)

    # Inicjalizuj kontroler duplikatów
    duplicate_controller = SimulationDuplicateController.new()

    # Główna pętla symulacji
    result = simulate_until_match(
      strategy.rules,
      target_draw.numbers,
      max_attempts,
      timeout_seconds,
      start_time,
      duplicate_controller
    )

    # Zapisz wynik z uwzględnieniem duplikatów
    finalize_simulation(simulation, result, start_time)
  rescue
    e ->
      Logger.error("Simulation error: #{inspect(e)}")

      Repo.update!(Ecto.Changeset.change(simulation, %{
        status: :error,
        result: %{"reason" => "error", "error_message" => Exception.message(e)},
        completed_at: DateTime.utc_now()
      }))
  end
end
```

#### Aktualizacja `finalize_simulation/4`

```elixir
defp finalize_simulation(simulation, result, start_time) do
  duration = System.monotonic_time(:second) - start_time

  case result do
    {:success, attempts, matched, controller} ->
      stats = SimulationDuplicateController.get_stats(controller)

      Repo.update!(Ecto.Changeset.change(simulation, %{
        status: :success,
        attempts_count: attempts,
        duration_seconds: duration,
        result: %{
          "matched_main" => matched[:main],
          "matched_euro" => matched[:euro],
          "attempts_count" => attempts,
          "final_draw" => target_draw.numbers,
          "duplicates_skipped" => stats.duplicates_skipped,
          "unique_attempts" => attempts
        },
        completed_at: DateTime.utc_now()
      }))

      # Zaktualizuj performance score strategii
      update_strategy_performance(simulation.strategy_id)

    {:timeout, reason, attempts, controller} ->
      stats = SimulationDuplicateController.get_stats(controller)

      Repo.update!(Ecto.Changeset.change(simulation, %{
        status: :timeout,
        attempts_count: attempts,
        duration_seconds: duration,
        result: %{
          "reason" => "timeout",
          "limit_reached" => reason,
          "attempts_count" => attempts,
          "duplicates_skipped" => stats.duplicates_skipped,
          "unique_attempts" => attempts
        },
        completed_at: DateTime.utc_now()
      }))
  end
end
```

### Korzyści mechanizmu

#### Wydajność
- **Oszczędność pamięci**: MapSet zapewnia O(1) sprawdzanie duplikatów
- **Optymalizacja CPU**: Unikanie redundantnych sprawdzeń trafień dla tych samych kombinacji
- **Skalowalność**: Mechanizm działa efektywnie nawet przy milionach prób

#### Dokładność wyników
- **Czyste statystyki**: `attempts_count` odzwierciedla rzeczywistą liczbę unikalnych prób
- **Realistyczna symulacja**: Każda kombinacja jest testowana dokładnie raz
- **Przewidywalne zachowanie**: Deterministyczne wyniki dla tych samych parametrów

#### Bezpieczeństwo
- **Deterministyczny hash**: MD5 zapewnia spójne identyfikatory kombinacji
- **Izolacja symulacji**: Każda symulacja ma własny kontroler duplikatów
- **Thread-safe**: Brak współdzielonego stanu między symulacjami

### Rozszerzenia mechanizmu

#### Opcjonalne logowanie duplikatów (debug mode)

```elixir
# W SimulationDuplicateController
def check_attempt(%__MODULE__{} = controller, %{main: main, euro: euro}, debug_mode \\ false) do
  combination_hash = generate_combination_hash(main, euro)

  if MapSet.member?(controller.attempts_set, combination_hash) do
    if debug_mode do
      Logger.debug("Duplicate attempt skipped: main=#{inspect(main)}, euro=#{inspect(euro)}")
    end

    {:duplicate, %__MODULE__{
      controller |
      duplicates_count: controller.duplicates_count + 1
    }}
  else
    {:unique, %__MODULE__{
      controller |
      attempts_set: MapSet.put(controller.attempts_set, combination_hash)
    }}
  end
end
```

#### Statystyki szczegółowe

```elixir
# Rozszerzone statystyki dla analizy
def get_detailed_stats(%__MODULE__{} = controller) do
  %{
    duplicates_skipped: controller.duplicates_count,
    unique_attempts: MapSet.size(controller.attempts_set),
    total_attempts: controller.duplicates_count + MapSet.size(controller.attempts_set),
    duplicate_ratio: controller.duplicates_count / max(1, MapSet.size(controller.attempts_set))
  }
end
```

### Testowanie mechanizmu

#### Testy jednostkowe

```elixir
describe "SimulationDuplicateController" do
  test "detects duplicate attempts correctly" do
    controller = SimulationDuplicateController.new()

    attempt1 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
    attempt2 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]} # duplikat
    attempt3 = %{main: [2, 8, 24, 35, 49], euro: [4, 10]} # unikalny

    # Pierwsza próba - unikalna
    assert {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt1)
    assert MapSet.size(controller.attempts_set) == 1

    # Druga próba - duplikat
    assert {:duplicate, controller} = SimulationDuplicateController.check_attempt(controller, attempt2)
    assert MapSet.size(controller.attempts_set) == 1
    assert controller.duplicates_count == 1

    # Trzecia próba - unikalna
    assert {:unique, controller} = SimulationDuplicateController.check_attempt(controller, attempt3)
    assert MapSet.size(controller.attempts_set) == 2
    assert controller.duplicates_count == 1
  end

  test "generates consistent hashes" do
    attempt1 = %{main: [1, 7, 23, 34, 50], euro: [3, 9]}
    attempt2 = %{main: [34, 1, 50, 23, 7], euro: [9, 3]} # te same liczby, inna kolejność

    hash1 = SimulationDuplicateController.generate_combination_hash(attempt1.main, attempt1.euro)
    hash2 = SimulationDuplicateController.generate_combination_hash(attempt2.main, attempt2.euro)

    assert hash1 == hash2
  end
end
```

#### Testy integracyjne

```elixir
test "simulation skips duplicates without affecting attempt count" do
  # Mock NumberGenerator zwracający zawsze tę samą kombinację
  # Sprawdź że attempts_count = 1, duplicates_skipped = max_attempts - 1
end
```

## 6. Zarządzanie stanem

**Architektura stanu**: Centralne zarządzanie w `PageLive`, komponenty bezstanowe.

**Stan zarządzany w PageLive**:
```elixir
socket
|> assign(:strategies, [])           # lista strategii użytkownika
|> assign(:simulations, [])          # historia symulacji
|> assign(:draws, [])                # dostępne losowania
|> assign(:running_simulation, nil)  # ID aktualnie działającej symulacji (opcjonalnie)
```

**Ładowanie danych**:
```elixir
defp load_simulations(socket) do
  user = socket.assigns.current_user
  simulations = if user, do: Simulations.list_simulations(user), else: []
  draws = Draws.list_draws(limit: 50)
  
  socket
  |> assign(:simulations, simulations)
  |> assign(:draws, draws)
end
```

**Event handler uruchomienia symulacji**:
```elixir
def handle_event("start_simulation", params, socket) do
  user = socket.assigns.current_user
  
  # Walidacja i utworzenie symulacji
  case Simulations.create_and_start_simulation(user, params) do
    {:ok, simulation} ->
      {:noreply,
       socket
       |> put_flash(:info, "Symulacja została uruchomiona")
       |> assign(:running_simulation, simulation.id)
       |> load_simulations()}
    
    {:error, %Ecto.Changeset{} = changeset} ->
      errors = extract_errors(changeset)
      {:noreply, put_flash(socket, :error, "Błąd walidacji: #{inspect(errors)}")}
    
    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Nie udało się uruchomić symulacji: #{reason}")}
  end
end
```

**Custom hooki**: Nie wymagane dla podstawowej wersji

**Opcjonalnie - Live tracking** (zaawansowana wersja):
```elixir
# Subskrypcja do PubSub dla live updates
def mount(_params, session, socket) do
  if connected?(socket) && socket.assigns.current_user do
    Phoenix.PubSub.subscribe(NumbersEvolution.PubSub, "simulations:#{socket.assigns.current_user.id}")
  end
  
  # ... reszta mount
end

def handle_info({:simulation_update, simulation_id, data}, socket) do
  # Aktualizacja postępu symulacji
  {:noreply, update_simulation_progress(socket, simulation_id, data)}
end
```

## 7. Integracja API

### Simulations.list_simulations/2

**Request**:
```elixir
Simulations.list_simulations(user, opts \\ [])
# opts: [limit: 50, order: :desc]
```

**Response**:
```elixir
[
  %Simulation{
    id: "uuid",
    status: :success,
    attempts_count: 125430,
    duration_seconds: 45.2,
    result: %{"matched_main" => [...], ...},
    strategy_id: "uuid",
    target_draw_id: "uuid",
    inserted_at: ~U[2025-11-15 10:00:00Z],
    ...
  },
  ...
]
```

**Implementacja**:
```elixir
def list_simulations(user, opts \\ []) do
  query = from s in Simulation,
    where: s.user_id == ^user.id,
    order_by: [desc: s.inserted_at],
    limit: ^(opts[:limit] || 50)
  
  Repo.all(query)
  |> Repo.preload([:strategy, :target_draw])  # opcjonalnie
end
```

### Simulations.create_and_start_simulation/2

**Request**:
```elixir
Simulations.create_and_start_simulation(user, params)
# params: %{
#   "strategy_id" => "uuid",
#   "target_draw_id" => "uuid",
#   "max_attempts" => "1000000",      # opcjonalnie
#   "timeout_seconds" => "300"        # opcjonalnie
# }
```

**Response**:
```elixir
{:ok, %Simulation{}} | {:error, %Ecto.Changeset{}} | {:error, atom()}
```

**Implementacja**:
```elixir
def create_and_start_simulation(user, params) do
  # 1. Waliduj że strategia należy do użytkownika
  strategy = Repo.get_by(Strategy, id: params["strategy_id"], user_id: user.id)
  
  unless strategy do
    return {:error, :strategy_not_found}
  end
  
  # 2. Waliduj że draw istnieje
  target_draw = Repo.get(Draw, params["target_draw_id"])
  
  unless target_draw do
    return {:error, :draw_not_found}
  end
  
  # 3. Utwórz symulację
  options = %{
    "max_attempts" => parse_int(params["max_attempts"], 1_000_000),
    "timeout_seconds" => parse_int(params["timeout_seconds"], 300)
  }
  
  changeset = Simulation.changeset(%Simulation{}, %{
    user_id: user.id,
    strategy_id: strategy.id,
    target_draw_id: target_draw.id,
    status: :pending,
    options: options
  })
  
  with {:ok, simulation} <- Repo.insert(changeset) do
    # 4. Uruchom symulację w tle
    start_simulation_task(simulation, strategy, target_draw)
    
    {:ok, simulation}
  end
end

defp start_simulation_task(simulation, strategy, target_draw) do
  Task.Supervisor.start_child(NumbersEvolution.TaskSupervisor, fn ->
    run_simulation(simulation, strategy, target_draw)
  end)
end
```

### Simulations.run_simulation/3 (backend logic)

**Algorytm symulacji**:
```elixir
defp run_simulation(simulation, strategy, target_draw) do
  # 1. Aktualizuj status na :running
  Repo.update!(Ecto.Changeset.change(simulation, %{
    status: :running,
    started_at: DateTime.utc_now()
  }))
  
  # 2. Parametry
  max_attempts = simulation.options["max_attempts"] || 1_000_000
  timeout_seconds = simulation.options["timeout_seconds"] || 300
  start_time = System.monotonic_time(:second)
  
  # 3. Główna pętla symulacji
  result = simulate_until_match(
    strategy.rules,
    target_draw.numbers,
    max_attempts,
    timeout_seconds,
    start_time,
    0
  )
  
  # 4. Zapisz wynik
  case result do
    {:success, attempts, matched_numbers} ->
      duration = System.monotonic_time(:second) - start_time
      
      Repo.update!(Ecto.Changeset.change(simulation, %{
        status: :success,
        attempts_count: attempts,
        duration_seconds: duration,
        result: %{
          "matched_main" => matched_numbers.main,
          "matched_euro" => matched_numbers.euro,
          "attempts_count" => attempts,
          "final_draw" => target_draw.numbers
        },
        completed_at: DateTime.utc_now()
      }))
      
      # 5. Aktualizuj performance_score strategii
      update_strategy_performance(strategy)
    
    {:timeout, reason, attempts} ->
      duration = System.monotonic_time(:second) - start_time
      
      Repo.update!(Ecto.Changeset.change(simulation, %{
        status: :timeout,
        attempts_count: attempts,
        duration_seconds: duration,
        result: %{
          "reason" => "timeout",
          "limit_reached" => reason,
          "attempts_count" => attempts
        },
        completed_at: DateTime.utc_now()
      }))
    
    {:error, reason} ->
      Repo.update!(Ecto.Changeset.change(simulation, %{
        status: :error,
        result: %{"reason" => "error", "error_message" => to_string(reason)},
        completed_at: DateTime.utc_now()
      }))
  end
end

defp simulate_until_match(rules, target, max_attempts, timeout, start_time, current_attempt) do
  # Sprawdź limity
  cond do
    current_attempt >= max_attempts ->
      {:timeout, "max_attempts", current_attempt}
    
    System.monotonic_time(:second) - start_time >= timeout ->
      {:timeout, "time_limit", current_attempt}
    
    true ->
      # Wygeneruj liczby według strategii
      generated = NumberGenerator.generate_numbers(rules)
      
      # Sprawdź czy trafiono
      if matches_target?(generated, target) do
        {:success, current_attempt + 1, generated}
      else
        # Opcjonalnie: co N prób wysyłaj update przez PubSub
        if rem(current_attempt, 10_000) == 0 do
          broadcast_progress(simulation.id, current_attempt)
        end
        
        simulate_until_match(rules, target, max_attempts, timeout, start_time, current_attempt + 1)
      end
  end
end

defp matches_target?(generated, target) do
  # Sprawdź czy trafiono 5+2
  main_match = MapSet.new(generated.main) == MapSet.new(target["main_numbers"])
  euro_match = MapSet.new(generated.euro) == MapSet.new(target["euro_numbers"])
  
  main_match && euro_match
end
```

### Draws.list_draws/1

**Request**:
```elixir
Draws.list_draws(opts \\ [])
# opts: [limit: 50, game_type: "eurojackpot"]
```

**Response**:
```elixir
[
  %Draw{
    id: "uuid",
    draw_date: ~D[2024-11-08],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 7, 23, 34, 50],
      "euro_numbers" => [3, 9]
    },
    ...
  },
  ...
]
```

**Implementacja**:
```elixir
def list_draws(opts \\ []) do
  query = from d in Draw,
    where: d.game_type == ^(opts[:game_type] || "eurojackpot"),
    order_by: [desc: d.draw_date],
    limit: ^(opts[:limit] || 100)
  
  Repo.all(query)
end
```

## 8. Interakcje użytkownika

### Uruchomienie symulacji

**Krok 1**: Wybór strategii z listy
- User klika na select i wybiera strategię
- Walidacja: Lista musi zawierać przynajmniej jedną strategię

**Krok 2**: Wybór target draw
- User klika na select i wybiera historyczne losowanie
- Wyświetlane jako: "2024-11-08 - 1, 7, 23, 34, 50 | 3, 9"

**Krok 3**: Opcjonalne dostosowanie limitów
- User rozwija collapsible "Opcjonalne limity"
- Wprowadza custom max_attempts lub timeout_seconds
- Placeholder pokazuje wartości domyślne

**Krok 4**: Uruchomienie
- Event: `phx-submit="start_simulation"`
- Loading state na przycisku podczas przetwarzania
- Handler w PageLive wywołuje `Simulations.create_and_start_simulation/2`

**Krok 5**: Feedback
- Sukces: Flash "Symulacja została uruchomiona", odświeżenie listy symulacji
- Błąd: Flash z komunikatem błędu, formularz pozostaje wypełniony

### Przeglądanie historii symulacji

**Interakcja**: Scrollowanie tabeli
- Tabela wyświetla ostatnie 50 symulacji
- Sortowanie: najnowsze na górze

**Interakcja**: Kliknięcie "Szczegóły"
- Event: `phx-click="view_simulation_details"` z `phx-value-id`
- Otwarcie modala ze szczegółami (TODO - może być w kolejnym etapie)

### Nawigacja do strategii (gdy brak strategii)

**Trigger**: Kliknięcie przycisku "Przejdź do strategii" w alercie
- Event: `phx-click="navigate"` z `phx-value-section="strategies"`
- Rezultat: Przełączenie na sekcję strategii

## 9. Warunki i walidacja

### Walidacja formularza (frontend)

**Sprawdzane w**: Template formularza

**Warunki**:
1. `strategy_id` - wymagane (`required` attribute)
2. `target_draw_id` - wymagane (`required` attribute)
3. `max_attempts` - min 1000, max 10,000,000 (HTML5 attributes)
4. `timeout_seconds` - min 10, max 3600 (HTML5 attributes)

**Wpływ na UI**:
- Przycisk submit disabled gdy pola wymagane puste (HTML5)
- Walidacja zakresu liczb przez przeglądarkę

### Walidacja backendu

**Sprawdzane w**: `Simulations.create_and_start_simulation/2`

**Reguły**:
1. Strategia musi należeć do użytkownika:
   ```elixir
   Repo.get_by(Strategy, id: strategy_id, user_id: user.id) || {:error, :unauthorized}
   ```

2. Target draw musi istnieć:
   ```elixir
   Repo.get(Draw, target_draw_id) || {:error, :not_found}
   ```

3. Limity w dozwolonych zakresach:
   ```elixir
   validate_number(:max_attempts, greater_than_or_equal_to: 1000, less_than_or_equal_to: 10_000_000)
   validate_number(:timeout_seconds, greater_than_or_equal_to: 10, less_than_or_equal_to: 3600)
   ```

**Wpływ na UI**:
- Flash message z błędem walidacji
- User musi poprawić dane i spróbować ponownie

### Warunek renderowania formularza

**Sprawdzany w**: `simulations_section/1`

**Warunek**: `@strategies == []`

**Wpływ na UI**:
- Jeśli brak strategii: alert z komunikatem i linkiem do strategii
- Jeśli są strategie: renderowanie formularza

### Warunek empty state w historii

**Sprawdzany w**: `simulations_section/1`

**Warunek**: `@simulations == []`

**Wpływ na UI**:
- Empty state z ikoną i komunikatem
- Link/przycisk do uruchomienia pierwszej symulacji

## 10. Obsługa błędów

### Błąd - brak strategii

**Scenariusz**: User próbuje uruchomić symulację ale nie posiada żadnej strategii

**Obsługa**: Warunek w template
```heex
<%= if @strategies == [] do %>
  <.alert kind="warning">
    Najpierw utwórz strategię, aby móc uruchamiać symulacje.
    <button phx-click="navigate" phx-value-section="strategies" class="btn btn-sm btn-primary mt-2">
      Przejdź do strategii
    </button>
  </.alert>
<% end %>
```

**UI**: Alert z linkiem do sekcji strategii

### Błąd - strategia nie należy do użytkownika

**Scenariusz**: Próba manipulacji ID strategii w request

**Obsługa** (backend):
```elixir
strategy = Repo.get_by(Strategy, id: params["strategy_id"], user_id: user.id)

unless strategy do
  {:error, :unauthorized}
end
```

**UI**: Flash error: "Nie masz dostępu do tej strategii"

### Błąd - symulacja timeout

**Scenariusz**: Symulacja przekroczyła limit czasu lub prób

**Obsługa** (w `run_simulation/3`):
```elixir
{:timeout, reason, attempts} ->
  Repo.update!(change(simulation, %{
    status: :timeout,
    result: %{"reason" => "timeout", "limit_reached" => reason, ...}
  }))
```

**UI**: 
- Status indicator pokazuje "Timeout" (pomarańczowy)
- Szczegóły pokazują: "Osiągnięto limit [prób/czasu] po X próbach"

### Błąd - crash podczas symulacji

**Scenariusz**: Nieoczekiwany błąd w logice generowania liczb

**Obsługa** (Task.Supervisor + try/rescue):
```elixir
try do
  run_simulation(simulation, strategy, target_draw)
rescue
  e ->
    Logger.error("Simulation crashed: #{inspect(e)}")
    
    Repo.update!(change(simulation, %{
      status: :error,
      result: %{"reason" => "error", "error_message" => Exception.message(e)}
    }))
end
```

**UI**:
- Status indicator pokazuje "Błąd" (czerwony)
- Szczegóły pokazują komunikat błędu
- Opcja "Spróbuj ponownie" (nowa symulacja z tymi samymi parametrami)

### Błąd - baza danych niedostępna

**Scenariusz**: Błąd połączenia z bazą podczas zapisu wyniku

**Obsługa** (Repo timeout + retry):
```elixir
case Repo.insert(changeset, timeout: 10_000) do
  {:ok, simulation} -> ...
  {:error, reason} ->
    Logger.error("Failed to create simulation: #{inspect(reason)}")
    {:error, :database_error}
end
```

**UI**: Flash error: "Błąd bazy danych. Spróbuj ponownie za chwilę."

## 11. Kroki implementacji

### Krok 1: Przygotowanie struktury

1.1. W `lib/numbers_evolution_web/components/sections_components.ex` dodać:
```elixir
attr :strategies, :list, required: true
attr :simulations, :list, required: true
attr :draws, :list, required: true

def simulations_section(assigns) do
  # Template
end
```

### Krok 2: Implementacja formularza

2.1. Dodać subkomponent `simulation_form/1`:
```elixir
attr :strategies, :list, required: true
attr :draws, :list, required: true

defp simulation_form(assigns) do
  ~H"""
  <form phx-submit="start_simulation" class="space-y-4">
    <div class="form-control">
      <label class="label">
        <span class="label-text">Wybierz strategię</span>
      </label>
      <select name="strategy_id" class="select select-bordered" required>
        <option value="" disabled selected>Wybierz strategię...</option>
        <%= for strategy <- @strategies do %>
          <option value={strategy.id}>{strategy.name}</option>
        <% end %>
      </select>
    </div>
    
    <div class="form-control">
      <label class="label">
        <span class="label-text">Target draw (losowanie docelowe)</span>
      </label>
      <select name="target_draw_id" class="select select-bordered" required>
        <option value="" disabled selected>Wybierz losowanie...</option>
        <%= for draw <- @draws do %>
          <option value={draw.id}>
            {Calendar.strftime(draw.draw_date, "%Y-%m-%d")} - 
            #{Enum.join(draw.numbers.main_numbers, ", ")} | 
            #{Enum.join(draw.numbers.euro_numbers, ", ")}
          </option>
        <% end %>
      </select>
    </div>
    
    <details class="collapse collapse-arrow bg-base-100">
      <summary class="collapse-title font-medium">
        Opcjonalne limity (zaawansowane)
      </summary>
      <div class="collapse-content space-y-4">
        <div class="form-control">
          <label class="label">
            <span class="label-text">Maksymalna liczba prób</span>
          </label>
          <input
            type="number"
            name="max_attempts"
            class="input input-bordered"
            placeholder="1000000"
            min="1000"
            max="10000000"
          />
          <label class="label">
            <span class="label-text-alt">Domyślnie: 1,000,000</span>
          </label>
        </div>
        
        <div class="form-control">
          <label class="label">
            <span class="label-text">Timeout (sekundy)</span>
          </label>
          <input
            type="number"
            name="timeout_seconds"
            class="input input-bordered"
            placeholder="300"
            min="10"
            max="36000"
          />
          <label class="label">
            <span class="label-text-alt">Domyślnie: 300s (5 minut)</span>
          </label>
        </div>
      </div>
    </details>
    
    <button type="submit" class="btn btn-primary w-full">
      <.icon name="hero-play" class="size-5" /> Uruchom symulację
    </button>
  </form>
  """
end
```

### Krok 3: Implementacja tabeli historii

3.1. Dodać subkomponent `simulations_table/1`:
```elixir
attr :simulations, :list, required: true

defp simulations_table(assigns) do
  ~H"""
  <div class="overflow-x-auto">
    <table class="table table-zebra">
      <thead>
        <tr>
          <th>Strategia</th>
          <th>Target Draw</th>
          <th>Data utworzenia</th>
          <th>Liczba prób</th>
          <th>Status</th>
          <th>Akcje</th>
        </tr>
      </thead>
      <tbody>
        <%= for sim <- @simulations do %>
          <tr>
            <td class="font-medium">{sim.strategy_id}</td>
            <td>
              {if sim.target_draw_id, 
                do: Calendar.strftime(sim.inserted_at, "%Y-%m-%d"), 
                else: "—"}
            </td>
            <td>{Calendar.strftime(sim.inserted_at, "%Y-%m-%d %H:%M")}</td>
            <td>
              {if sim.result && sim.result["attempts_count"], 
                do: format_number(sim.result["attempts_count"]), 
                else: "—"}
            </td>
            <td>
              <.status_indicator status={sim.status} />
            </td>
            <td>
              <button phx-click="view_simulation_details" phx-value-id={sim.id} class="btn btn-sm btn-ghost">
                <.icon name="hero-eye" class="size-4" /> Szczegóły
              </button>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
  """
end
```

### Krok 4: Event handlers w PageLive

4.1. Dodać handler uruchomienia symulacji:
```elixir
def handle_event("start_simulation", params, socket) do
  user = socket.assigns.current_user
  
  case Simulations.create_and_start_simulation(user, params) do
    {:ok, _simulation} ->
      {:noreply,
       socket
       |> put_flash(:info, "Symulacja została uruchomiona")
       |> load_simulations()}
    
    {:error, reason} ->
      message = format_error(reason)
      {:noreply, put_flash(socket, :error, "Nie udało się uruchomić symulacji: #{message}")}
  end
end

defp format_error(:strategy_not_found), do: "Strategia nie znaleziona"
defp format_error(:draw_not_found), do: "Losowanie nie znalezione"
defp format_error(:unauthorized), do: "Brak dostępu do tej strategii"
defp format_error(reason), do: inspect(reason)
```

### Krok 5: Backend - Simulations context

5.1. Utworzyć `lib/numbers_evolution/simulations.ex`:
```elixir
defmodule NumbersEvolution.Simulations do
  import Ecto.Query
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Simulations.Simulation
  alias NumbersEvolution.Strategies.Strategy
  alias NumbersEvolution.Draws.Draw

  def list_simulations(user, opts \\ []) do
    query = from s in Simulation,
      where: s.user_id == ^user.id,
      order_by: [desc: s.inserted_at],
      limit: ^(opts[:limit] || 50)
    
    Repo.all(query)
  end
  
  def create_and_start_simulation(user, params) do
    with {:ok, strategy} <- validate_strategy(user, params["strategy_id"]),
         {:ok, target_draw} <- validate_draw(params["target_draw_id"]),
         {:ok, simulation} <- create_simulation(user, strategy, target_draw, params) do
      
      start_simulation_task(simulation, strategy, target_draw)
      
      {:ok, simulation}
    end
  end
  
  defp validate_strategy(user, strategy_id) do
    case Repo.get_by(Strategy, id: strategy_id, user_id: user.id) do
      nil -> {:error, :strategy_not_found}
      strategy -> {:ok, strategy}
    end
  end
  
  defp validate_draw(draw_id) do
    case Repo.get(Draw, draw_id) do
      nil -> {:error, :draw_not_found}
      draw -> {:ok, draw}
    end
  end
  
  defp create_simulation(user, strategy, target_draw, params) do
    options = %{
      "max_attempts" => parse_int(params["max_attempts"], 1_000_000),
      "timeout_seconds" => parse_int(params["timeout_seconds"], 300)
    }
    
    %Simulation{}
    |> Simulation.changeset(%{
      user_id: user.id,
      strategy_id: strategy.id,
      target_draw_id: target_draw.id,
      status: :pending,
      options: options
    })
    |> Repo.insert()
  end
  
  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default
  defp parse_int(value, _default) when is_integer(value), do: value
  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
  
  defp start_simulation_task(simulation, strategy, target_draw) do
    Task.Supervisor.start_child(NumbersEvolution.TaskSupervisor, fn ->
      run_simulation(simulation, strategy, target_draw)
    end)
  end
  
  # run_simulation/3 - implementacja w kolejnych krokach
end
```

### Krok 6: Implementacja logiki symulacji

6.1. Dodać `run_simulation/3` w Simulations context:
```elixir
defp run_simulation(simulation, strategy, target_draw) do
  try do
    # Aktualizuj status na :running
    simulation = Repo.update!(Ecto.Changeset.change(simulation, %{
      status: :running,
      started_at: DateTime.utc_now()
    }))
    
    # Parametry
    max_attempts = simulation.options["max_attempts"] || 1_000_000
    timeout_seconds = simulation.options["timeout_seconds"] || 300
    start_time = System.monotonic_time(:second)
    
    # Główna pętla symulacji
    result = simulate_until_match(
      strategy.rules,
      target_draw.numbers,
      max_attempts,
      timeout_seconds,
      start_time
    )
    
    # Zapisz wynik
    finalize_simulation(simulation, result, start_time)
  rescue
    e ->
      Logger.error("Simulation error: #{inspect(e)}")
      
      Repo.update!(Ecto.Changeset.change(simulation, %{
        status: :error,
        result: %{"reason" => "error", "error_message" => Exception.message(e)},
        completed_at: DateTime.utc_now()
      }))
  end
end

defp simulate_until_match(rules, target, max_attempts, timeout, start_time, current_attempt \\ 0) do
  # Sprawdź limity
  cond do
    current_attempt >= max_attempts ->
      {:timeout, "max_attempts", current_attempt}
    
    System.monotonic_time(:second) - start_time >= timeout ->
      {:timeout, "time_limit", current_attempt}
    
    true ->
      # Wygeneruj liczby
      generated = NumbersEvolution.NumberGenerator.generate_numbers(rules)
      
      # Sprawdź trafienie
      if matches_target?(generated, target) do
        {:success, current_attempt + 1, generated}
      else
        simulate_until_match(rules, target, max_attempts, timeout, start_time, current_attempt + 1)
      end
  end
end

defp matches_target?(generated, target) do
  main_match = MapSet.new(generated[:main]) == MapSet.new(target["main_numbers"])
  euro_match = MapSet.new(generated[:euro]) == MapSet.new(target["euro_numbers"])
  
  main_match && euro_match
end

defp finalize_simulation(simulation, result, start_time) do
  duration = System.monotonic_time(:second) - start_time
  
  case result do
    {:success, attempts, matched} ->
      Repo.update!(Ecto.Changeset.change(simulation, %{
        status: :success,
        attempts_count: attempts,
        duration_seconds: duration,
        result: %{
          "matched_main" => matched[:main],
          "matched_euro" => matched[:euro],
          "attempts_count" => attempts
        },
        completed_at: DateTime.utc_now()
      }))
      
      # Zaktualizuj performance score strategii
      update_strategy_performance(simulation.strategy_id)
    
    {:timeout, reason, attempts} ->
      Repo.update!(Ecto.Changeset.change(simulation, %{
        status: :timeout,
        attempts_count: attempts,
        duration_seconds: duration,
        result: %{
          "reason" => "timeout",
          "limit_reached" => reason,
          "attempts_count" => attempts
        },
        completed_at: DateTime.utc_now()
      }))
  end
end

defp update_strategy_performance(strategy_id) do
  # Oblicz medianę liczby prób dla strategii
  median = from(s in Simulation,
    where: s.strategy_id == ^strategy_id and s.status == :success,
    select: fragment("percentile_cont(0.5) WITHIN GROUP (ORDER BY ?)", s.attempts_count)
  ) |> Repo.one()
  
  if median do
    from(s in Strategy, where: s.id == ^strategy_id)
    |> Repo.update_all(set: [performance_score: median])
  end
end
```

### Krok 7: Number Generator

7.1. Utworzyć moduł `lib/numbers_evolution/number_generator.ex`:
```elixir
defmodule NumbersEvolution.NumberGenerator do
  @doc """
  Generuje zestaw liczb zgodnie z regułami strategii.
  
  Returns: %{main: [1,7,23,34,50], euro: [3,9]}
  """
  def generate_numbers(rules) do
    %{
      main: generate_main_numbers(rules["main_numbers"]),
      euro: generate_euro_numbers(rules["euro_numbers"])
    }
  end
  
  defp generate_main_numbers(rules) do
    # Implementacja generowania głównych liczb
    # według ratio, wag, preferowanych liczb
    # TODO - szczegółowa implementacja
    
    # Przykład prostego generatora:
    1..50
    |> Enum.to_list()
    |> Enum.shuffle()
    |> Enum.take(5)
    |> Enum.sort()
  end
  
  defp generate_euro_numbers(rules) do
    # Implementacja generowania euro liczb
    # TODO - szczegółowa implementacja
    
    1..12
    |> Enum.to_list()
    |> Enum.shuffle()
    |> Enum.take(2)
    |> Enum.sort()
  end
end
```

### Krok 8: Migracja bazy danych

8.1. Utworzyć migrację symulacji:
```bash
mix ecto.gen.migration create_simulations
```

8.2. W migracji:
```elixir
def change do
  create table(:simulations, primary_key: false) do
    add :id, :binary_id, primary_key: true
    add :status, :string, null: false, default: "pending"
    add :attempts_count, :integer
    add :duration_seconds, :float
    add :result, :map
    add :options, :map, default: %{}
    add :started_at, :utc_datetime
    add :completed_at, :utc_datetime
    add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
    add :strategy_id, references(:strategies, type: :binary_id, on_delete: :nilify_all), null: false
    add :target_draw_id, references(:draws, type: :binary_id, on_delete: :restrict), null: false
    
    timestamps(type: :utc_datetime)
  end
  
  create index(:simulations, [:user_id])
  create index(:simulations, [:strategy_id])
  create index(:simulations, [:target_draw_id])
  create index(:simulations, [:status])
  create index(:simulations, [:inserted_at])
end
```

### Krok 9: Testowanie

9.1. Testy context:
```elixir
describe "create_and_start_simulation/2" do
  test "creates simulation with valid params", %{user: user} do
    strategy = insert(:strategy, user: user)
    draw = insert(:draw)
    
    params = %{
      "strategy_id" => strategy.id,
      "target_draw_id" => draw.id
    }
    
    assert {:ok, simulation} = Simulations.create_and_start_simulation(user, params)
    assert simulation.status == :pending
    assert simulation.strategy_id == strategy.id
    assert simulation.target_draw_id == draw.id
  end
  
  test "returns error when strategy doesn't belong to user", %{user: user} do
    other_strategy = insert(:strategy)
    draw = insert(:draw)
    
    params = %{
      "strategy_id" => other_strategy.id,
      "target_draw_id" => draw.id
    }
    
    assert {:error, :strategy_not_found} = Simulations.create_and_start_simulation(user, params)
  end
end

describe "run_simulation/3" do
  test "completes successfully when match found quickly" do
    # Test z mockiem NumberGenerator
  end
  
  test "timeouts when max_attempts reached" do
    # Test z mockiem który nigdy nie trafia
  end
end
```

9.2. Testy LiveView:
```elixir
test "displays simulation form with strategies and draws", %{conn: conn} do
  user = insert(:user)
  strategy = insert(:strategy, user: user, name: "Test Strategy")
  draw = insert(:draw, draw_date: ~D[2024-11-08])
  
  conn = log_in_user(conn, user)
  {:ok, view, _html} = live(conn, "/")
  
  view |> element("button", "Symulacje") |> render_click()
  
  assert has_element?(view, "option", "Test Strategy")
  assert has_element?(view, "option", ~r/2024-11-08/)
end

test "starts simulation when form submitted", %{conn: conn} do
  user = insert(:user)
  strategy = insert(:strategy, user: user)
  draw = insert(:draw)
  
  conn = log_in_user(conn, user)
  {:ok, view, _html} = live(conn, "/")
  
  view |> element("button", "Symulacje") |> render_click()
  
  view
  |> form("#simulation-form", %{
    "strategy_id" => strategy.id,
    "target_draw_id" => draw.id
  })
  |> render_submit()
  
  assert render(view) =~ "Symulacja została uruchomiona"
end
```

### Krok 10: Optymalizacje

10.1. Dodać Task.Supervisor do application.ex:
```elixir
children = [
  # ...
  {Task.Supervisor, name: NumbersEvolution.TaskSupervisor}
]
```

10.2. Dodać indeksy bazodanowe dla częstych queries

10.3. Rozważyć optymalizację `simulate_until_match` (batch processing, early exit patterns)

---

**Status implementacji**: ✅ Struktura zaimplementowana, logika symulacji TODO
**Priorytet dla MVP**: WYSOKI (główna funkcjonalność aplikacji)
**Zależności**: Wymaga `Strategies`, `Draws` contexts, Task.Supervisor
**Następne kroki**: Implementacja szczegółowej logiki `NumberGenerator`, live tracking (opcjonalnie)

