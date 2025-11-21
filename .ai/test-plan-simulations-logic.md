# Test Plan: Logika symulacji (Simulations Logic)

## 1. Wprowadzenie

### Moduł docelowy
Główna logika symulacji w `NumbersEvolution.Simulations` oraz `SimulationDuplicateController`.

### Dlaczego warto testować
- **Algorytmy porównywania wyników z target draw** - kluczowa logika biznesowa symulacji
- **Liczenie prób i śledzenie czasu** - zapobiega nieskończonym pętlom, timeout'y
- **Obsługa timeout'ów i limitów** - bezpieczeństwo i wydajność
- **Zarządzanie duplikatami** - optymalizacja i dokładność wyników
- **Krytyczna dla integralności danych** - błędne wyniki symulacji wpływają na całą aplikację

### Zakres testowania
- **Unit tests** - wszystkie publiczne i prywatne funkcje logiki symulacji
- **Integration** - pełne przepływy symulacji z mockowaniem
- **Edge cases** - graniczne warunki, duże liczby, błędy
- **Performance** - timeout handling, memory usage
- **Concurrency** - równoległe symulacje, izolacja stanów

## 2. Funkcje do przetestowania

### 2.1 Główna logika symulacji (simulations.ex)

#### **Porównywanie wyników: `matches_target?/2`**
**Cel:** Sprawdzenie czy wygenerowane liczby dokładnie pasują do target draw (5+2)

#### **Główna pętla symulacji: `simulate_until_match/9`**
**Cel:** Rekursywna logika symulacji z obsługą limitów i duplikatów

#### **Sprawdzanie limitów: `check_simulation_limits/4`**
**Cel:** Walidacja timeout'ów i maksymalnej liczby prób

#### **Obsługa pojedynczej próby: `process_simulation_attempt/9`**
**Cel:** Logika pojedynczego cyklu symulacji

#### **Obsługa unikalnej próby: `handle_unique_attempt/10`**
**Cel:** Decyzja o kontynuacji lub sukcesie

#### **Finalizacja symulacji: `finalize_simulation/5`**
**Cel:** Zapis wyników i aktualizacja statystyk

#### **Aktualizacja performance: `update_strategy_performance/1`**
**Cel:** Obliczanie mediany i aktualizacja wyników strategii

#### **Obliczanie mediany: `calculate_median/1`**
**Cel:** Statystyczna miara skuteczności strategii

### 2.2 Kontroler duplikatów (SimulationDuplicateController)

#### **Sprawdzanie prób: `check_attempt/2`**
**Cel:** Detekcja i obsługa duplikowanych kombinacji

#### **Generowanie hasha: `generate_combination_hash/2`**
**Cel:** Deterministyczne hashowanie kombinacji dla porównania

#### **Statystyki duplikatów: `get_stats/1`, `get_detailed_stats/1`**
**Cel:** Raportowanie efektywności kontroli duplikatów

## 3. Szczegółowe scenariusze testowe

### 3.1 Testy porównywania wyników `matches_target?/2`

#### **Dokładne dopasowanie (5+2)**
```elixir
# Test case: perfect match - all 5 main + 2 euro numbers match
generated = %{main: [7, 15, 23, 34, 42], euro: [3, 9]}
target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}
# Expected: true
```

#### **Częściowe dopasowanie**
```elixir
# Test case: 4 main + 2 euro match (not enough)
generated = %{main: [7, 15, 23, 34, 41], euro: [3, 9]}  # main[4] different
target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}
# Expected: false

# Test case: 5 main + 1 euro match (not enough)
generated = %{main: [7, 15, 23, 34, 42], euro: [3, 8]}  # euro[1] different
target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}
# Expected: false

# Test case: 4 main + 1 euro match (not enough)
generated = %{main: [7, 15, 23, 34, 41], euro: [3, 8]}  # both different
target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}
# Expected: false
```

#### **Brak dopasowania**
```elixir
# Test case: completely different numbers
generated = %{main: [1, 2, 3, 4, 5], euro: [1, 2]}
target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}
# Expected: false
```

#### **Edge cases**
```elixir
# Test case: same numbers but different order
generated = %{main: [42, 7, 23, 15, 34], euro: [9, 3]}  # same numbers, different order
target = %{main_numbers: [7, 15, 23, 34, 42], euro_numbers: [3, 9]}
# Expected: true (order doesn't matter)

# Test case: empty lists
generated = %{main: [], euro: []}
target = %{main_numbers: [], euro_numbers: []}
# Expected: true

# Test case: nil values
generated = %{main: nil, euro: nil}
target = %{main_numbers: nil, euro_numbers: nil}
# Expected: error or false
```

### 3.2 Testy sprawdzania limitów `check_simulation_limits/4`

#### **Przekroczenie maksymalnej liczby prób**
```elixir
# Test case: exactly at limit
current_attempt = 1_000_000
max_attempts = 1_000_000
# Expected: {:timeout, "max_attempts"}

# Test case: over limit
current_attempt = 1_000_001
max_attempts = 1_000_000
# Expected: {:timeout, "max_attempts"}
```

#### **Przekroczenie timeout'u**
```elixir
# Test case: exactly at timeout
start_time = System.monotonic_time(:second) - 300  # 5 minutes ago
timeout_seconds = 300
# Expected: {:timeout, "time_limit"}

# Test case: over timeout
start_time = System.monotonic_time(:second) - 301  # just over 5 minutes
timeout_seconds = 300
# Expected: {:timeout, "time_limit"}
```

#### **Kontynuacja symulacji**
```elixir
# Test case: under limits
current_attempt = 500_000
max_attempts = 1_000_000
start_time = System.monotonic_time(:second) - 100  # 100 seconds ago
timeout_seconds = 300
# Expected: {:continue, nil}
```

### 3.3 Testy głównej pętli symulacji `simulate_until_match/9`

#### **Sukces w pierwszej próbie**
```elixir
# Mock successful generation matching target
# Expected: {:success, 1, matched_numbers, controller}
```

#### **Sukces po wielu próbach**
```elixir
# Mock multiple failures then success
# Expected: {:success, attempts_count, matched_numbers, controller}
```

#### **Timeout po maksymalnej liczbie prób**
```elixir
# Mock reaching max_attempts limit
# Expected: {:timeout, "max_attempts", attempts_count, controller}
```

#### **Timeout po czasie**
```elixir
# Mock timeout_seconds reached
# Expected: {:timeout, "time_limit", attempts_count, controller}
```

#### **Obsługa duplikatów**
```elixir
# Mock duplicate generation, then success
# Expected: duplicate skipped, attempt counter not incremented
```

### 3.4 Testy kontrolera duplikatów (SimulationDuplicateController)

#### **Sprawdzanie duplikatów**
```elixir
# Test case: first attempt - unique
controller = SimulationDuplicateController.new()
attempt = %{main: [1, 2, 3, 4, 5], euro: [1, 2]}
# Expected: {:unique, updated_controller}

# Test case: same attempt again - duplicate
# Expected: {:duplicate, updated_controller}
```

#### **Różne kombinacje tych samych liczb**
```elixir
# Test case: same numbers, different order - duplicate
attempt1 = %{main: [1, 2, 3, 4, 5], euro: [1, 2]}
attempt2 = %{main: [5, 1, 3, 2, 4], euro: [2, 1]}  # same numbers
# Expected: attempt2 is duplicate
```

#### **Hash kombinacji**
```elixir
# Test case: deterministic hash
hash1 = SimulationDuplicateController.generate_combination_hash([1, 2, 3, 4, 5], [1, 2])
hash2 = SimulationDuplicateController.generate_combination_hash([5, 1, 3, 2, 4], [2, 1])
# Expected: hash1 == hash2
```

#### **Statystyki duplikatów**
```elixir
# Test case: detailed stats after multiple operations
controller = SimulationDuplicateController.new()
# Add several unique attempts, then duplicates
stats = SimulationDuplicateController.get_detailed_stats(controller)
# Expected: correct counts and ratios
```

### 3.5 Testy obliczania mediany `calculate_median/1`

#### **Nieparzysta liczba elementów**
```elixir
# Test case: 5 elements - middle value
list = [1, 2, 3, 4, 5]
# Expected: 3.0

# Test case: 1 element
list = [42]
# Expected: 42.0
```

#### **Parzysta liczba elementów**
```elixir
# Test case: 4 elements - average of middle two
list = [1, 2, 3, 4]
# Expected: 2.5 (average of 2 and 3)

# Test case: 2 elements
list = [10, 20]
# Expected: 15.0
```

#### **Edge cases**
```elixir
# Test case: empty list
list = []
# Expected: error or handle gracefully

# Test case: unsorted list
list = [5, 1, 3, 2, 4]
# Expected: function should handle unsorted (but in practice it's pre-sorted)
```

#### **Duże liczby i precyzja**
```elixir
# Test case: large numbers
list = [100_000, 200_000, 300_000]
# Expected: 200_000.0

# Test case: floating point precision
list = [1, 2, 2, 3, 4]
# Expected: 2.0
```

## 4. Test Data Factory

### 4.1 Testowe strategie i losowania
```elixir
defmodule TestData.Simulations do
  def sample_strategy do
    %NumbersEvolution.Strategies.Strategy{
      id: "test-strategy-id",
      name: "Test Strategy",
      rules: %{
        main_numbers: %{
          ratio_even_odd: [2, 3],
          ratio_low_high: [3, 2],
          preferred_hot: [7, 15, 23],
          preferred_cold: [11, 34],
          weights: %{hot: 0.5, cold: 0.2, random: 0.3}
        },
        euro_numbers: %{
          ratio_even_odd: [1, 1],
          preferred: [3, 7],
          weights: %{hot: 0.6, random: 0.4}
        }
      }
    }
  end

  def sample_target_draw do
    %NumbersEvolution.Draws.Draw{
      id: "test-draw-id",
      numbers: %{
        main_numbers: [7, 15, 23, 34, 42],
        euro_numbers: [3, 9]
      }
    }
  end

  def matching_generated_numbers do
    %{main: [7, 15, 23, 34, 42], euro: [3, 9]}
  end

  def non_matching_generated_numbers do
    %{main: [1, 2, 3, 4, 5], euro: [1, 2]}
  end
end
```

### 4.2 Testowe scenariusze symulacji
```elixir
defmodule TestScenarios.Simulations do
  def quick_success_scenario do
    # Strategy generates matching numbers on first try
    %{strategy: sample_strategy(), target: sample_target_draw(), max_attempts: 1000}
  end

  def timeout_scenario do
    # Strategy never generates matching numbers, hits timeout
    %{strategy: never_matching_strategy(), target: sample_target_draw(), timeout: 1}
  end

  def max_attempts_scenario do
    # Strategy never generates matching numbers, hits max attempts
    %{strategy: never_matching_strategy(), target: sample_target_draw(), max_attempts: 10}
  end

  def duplicates_scenario do
    # Strategy generates many duplicates before success
    %{strategy: duplicate_strategy(), target: sample_target_draw(), max_attempts: 1000}
  end
end
```

## 5. Struktura testów

### 5.1 Organizacja plików
```
test/numbers_evolution/simulations/
├── simulations_logic_test.exs           # Główna logika symulacji
├── simulation_duplicate_controller_test.exs  # Kontroler duplikatów
├── simulation_matching_test.exs         # Testy matches_target?
├── simulation_limits_test.exs           # Testy limitów i timeout'ów
├── simulation_median_test.exs           # Testy obliczania mediany
```

### 5.2 Setup testowy
```elixir
defmodule NumbersEvolution.SimulationsLogicTest do
  use NumbersEvolution.DataCase, async: true

  alias NumbersEvolution.Simulations
  alias NumbersEvolution.Simulations.SimulationDuplicateController

  # Helper to create mock strategy and target
  def create_mock_simulation_data do
    strategy = TestData.Simulations.sample_strategy()
    target_draw = TestData.Simulations.sample_target_draw()
    {strategy, target_draw}
  end

  # Helper to test private functions by making them testable
  def test_private_function(module, function_name, args) do
    apply(module, function_name, args)
  end
end
```

### 5.3 Mockowanie generatora
```elixir
# Mock NumbersEvolution.Strategies.Generator for controlled testing
Mox.defmock(GeneratorMock, for: NumbersEvolution.Strategies.Generator)

# In tests:
expect(GeneratorMock, :generate_numbers, fn _strategy, _opts ->
  {:ok, TestData.Simulations.matching_generated_numbers()}
end)
```

## 6. Strategie testowania

### 6.1 Testowanie funkcji prywatnych
```elixir
# Approach 1: Test through public API
test "matches_target? logic through simulate_until_match" do
  # Test the logic indirectly through the public flow
end

# Approach 2: Make private functions testable in test environment
@doc false
def test_matches_target?(generated, target), do: matches_target?(generated, target)
```

### 6.2 Testowanie rekursji
```elixir
# Limit recursion depth in tests to prevent stack overflow
test "simulate_until_match with depth limit" do
  # Mock generator to return non-matching numbers up to depth limit
  # Then return matching on limit + 1
end
```

### 6.3 Testowanie współbieżności
```elixir
# Test parallel simulations don't interfere with each other
test "multiple simulations run independently" do
  # Start multiple simulations concurrently
  # Verify each has its own duplicate controller state
end
```

## 7. Priorytety testowania

### Wysoki priorytet (krytyczne dla bezpieczeństwa)
1. **`matches_target?/2`** - błędna logika = błędne wyniki symulacji
2. **`check_simulation_limits/4`** - zapobiega nieskończonym pętlom
3. **`calculate_median/1`** - wpływa na ranking strategii
4. **Duplicate controller** - zapewnia dokładność wyników

### Średni priorytet (poprawność biznesowa)
5. **`simulate_until_match/9`** - główna logika symulacji
6. **Limit handling** - timeout vs max attempts
7. **Performance stats** - dokładność pomiarów czasu

### Niski priorytet (UX)
8. **Progress broadcasting** - UI updates
9. **Error messages** - czytelność błędów
10. **Detailed stats** - dodatkowe metryki

## 8. Metryki sukcesu testów

- **Pokrycie kodu:** >95% dla wszystkich funkcji w simulations.ex i SimulationDuplicateController
- **Performance:** Testy symulacji kończą się w <5 sekund
- **Memory:** Brak wycieków pamięci w długich symulacjach
- **Concurrency:** Izolacja między równoległymi symulacjami
- **Accuracy:** Wszystkie edge cases mediany i dopasowań

## 9. Uruchamianie testów

```bash
# Wszystkie testy symulacji
mix test test/numbers_evolution/simulations/

# Tylko logika główna
mix test test/numbers_evolution/simulations/simulations_logic_test.exs

# Tylko kontroler duplikatów
mix test test/numbers_evolution/simulations/simulation_duplicate_controller_test.exs

# Z pokryciem
mix test --cover test/numbers_evolution/simulations/

# Testy współbieżności
mix test --include concurrency test/numbers_evolution/simulations/
```

## 10. Integration z CI/CD

- **Fast tests** - podstawowa logika bez długich symulacji
- **Slow tests** - pełne symulacje tylko na nightly builds
- **Memory tests** - sprawdzanie wycieków pamięci
- **Concurrency tests** - weryfikacja izolacji między symulacjami

---

## Podsumowanie wymagań

**Obecne pokrycie:** Brak dedykowanych testów dla logiki symulacji  
**Wymagane pokrycie:** 95%+ dla wszystkich funkcji  
**Krytyczne braki:** `matches_target?/2`, limity, duplikaty, mediana  
**Szacowany czas:** 6-8 godzin implementacji + testów integracyjnych  
**Ryzyko:** Błędy w logice symulacji wpływają na całą aplikację
