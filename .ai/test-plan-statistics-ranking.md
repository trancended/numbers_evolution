# Test Plan: Obliczanie statystyk i rankingów

## 1. Wprowadzenie

### Moduł docelowy
Statystyki i ranking strategii w `NumbersEvolution.Simulations` oraz `NumbersEvolution.Strategies`.

### Dlaczego warto testować
- **Obliczanie mediany liczby prób** - główna metryka sukcesu strategii (mniej wrażliwa na outliery niż średnia)
- **Aktualizacja performance score** - wpływa na ranking i rekomendacje strategii
- **Sortowanie strategii wg skuteczności** - kluczowa funkcjonalność UI
- **Dokładność rankingów** - błędne obliczenia wpływają na decyzje użytkowników
- **Skalowalność** - wydajność dla dużej liczby strategii i symulacji

### Zakres testowania
- **Unit tests** - funkcje obliczeniowe (mediana, performance)
- **Integration** - pełne aktualizacje po symulacjach
- **Data integrity** - spójność performance score z wynikami symulacji
- **Edge cases** - puste zbiory, duplikaty, wartości graniczne
- **Performance** - wydajność dla dużych zbiorów danych

## 2. Funkcje do przetestowania

### 2.1 Obliczanie statystyk (simulations.ex)

#### **Obliczanie mediany: `calculate_median/1`**
**Cel:** Statystyczna miara centralna dla skuteczności strategii

#### **Aktualizacja performance: `update_strategy_performance/1`**
**Cel:** Aktualizacja performance_score strategii po każdej udanej symulacji

### 2.2 Schemat strategii (strategy.ex)

#### **Performance changeset: `performance_changeset/2`**
**Cel:** Walidacja i aktualizacja performance score

### 2.3 Logika rankingów (strategies.ex)

#### **Sortowanie strategii: funkcje list_strategies z sortowaniem**
**Cel:** Poprawne sortowanie wg performance_score

## 3. Szczegółowe scenariusze testowe

### 3.1 Testy obliczania mediany `calculate_median/1`

#### **Nieparzysta liczba elementów**
```elixir
# Test case: 5 elements - returns middle value
list = [1, 2, 3, 4, 5]
# Expected: 3.0

# Test case: 1 element - returns the only value
list = [42]
# Expected: 42.0

# Test case: 3 elements
list = [10, 20, 30]
# Expected: 20.0
```

#### **Parzysta liczba elementów**
```elixir
# Test case: 4 elements - average of two middle values
list = [1, 2, 3, 4]
# Expected: 2.5 (average of 2 and 3)

# Test case: 2 elements - average of both
list = [10, 20]
# Expected: 15.0

# Test case: 6 elements
list = [1, 2, 3, 4, 5, 6]
# Expected: 3.5 (average of 3 and 4)
```

#### **Edge cases**
```elixir
# Test case: empty list
list = []
# Expected: error or handle gracefully (depends on implementation)

# Test case: unsorted list
list = [5, 1, 3, 2, 4]
# Expected: should work (function handles unsorted input)

# Test case: list with duplicates
list = [1, 2, 2, 3, 3, 3]
# Expected: correct median regardless of duplicates

# Test case: negative numbers
list = [-5, -3, -1, 1, 3, 5]
# Expected: -1.0 (middle value for odd count)

# Test case: floating point numbers
list = [1.1, 2.2, 3.3, 4.4]
# Expected: 2.75 (average of 2.2 and 3.3)
```

#### **Duże zbiory danych**
```elixir
# Test case: large dataset (1000 elements)
list = Enum.to_list(1..1000)
# Expected: 500.5 (average of 500 and 501)

# Test case: very large numbers
list = [100_000, 200_000, 300_000]
# Expected: 200_000.0

# Test case: very small numbers
list = [0.001, 0.002, 0.003, 0.004]
# Expected: 0.0025
```

#### **Precyzja obliczeń**
```elixir
# Test case: floating point precision
list = [1, 2, 2, 2, 3]
# Expected: 2.0

# Test case: integer division vs float
list = [1, 2, 3, 4, 5, 6]
# Expected: 3.5 (not 3 due to float division)
```

### 3.2 Testy aktualizacji performance `update_strategy_performance/1`

#### **Strategia z wieloma symulacjami**
```elixir
# Test case: strategy with multiple successful simulations
# Create strategy, add several simulations with different attempt counts
# Expected: performance_score = median of attempt counts

# Example data:
# Simulations: [100, 200, 150, 175, 125]
# Sorted: [100, 125, 150, 175, 200]
# Median: 150.0
```

#### **Strategia z jedną symulacją**
```elixir
# Test case: strategy with single simulation
# Expected: performance_score = attempts_count of that simulation
```

#### **Strategia bez udanych symulacji**
```elixir
# Test case: strategy with only failed simulations
# Expected: performance_score remains nil or unchanged
```

#### **Aktualizacja po nowej symulacji**
```elixir
# Test case: add new simulation to existing strategy
# Expected: performance_score recalculated with new median
```

#### **Symulacje w trakcie przetwarzania**
```elixir
# Test case: running simulation doesn't affect performance calculation
# Expected: only successful simulations count
```

### 3.3 Testy performance changeset `performance_changeset/2`

#### **Prawidłowe wartości**
```elixir
# Test case: valid performance score
strategy = %Strategy{performance_score: nil}
changeset = Strategy.performance_changeset(strategy, 150.5)
# Expected: valid changeset, performance_score updated

# Test case: update existing score
strategy = %Strategy{performance_score: 200.0}
changeset = Strategy.performance_changeset(strategy, 150.5)
# Expected: valid changeset, performance_score updated
```

#### **Nieprawidłowe wartości**
```elixir
# Test case: negative performance score
changeset = Strategy.performance_changeset(strategy, -50.0)
# Expected: invalid changeset (if validation exists)

# Test case: nil value
changeset = Strategy.performance_changeset(strategy, nil)
# Expected: valid changeset (nil is acceptable)
```

### 3.4 Testy sortowania strategii

#### **Sortowanie wg performance_score**
```elixir
# Test case: strategies sorted by descending performance_score
strategies = [
  %{name: "Bad", performance_score: 500.0},
  %{name: "Good", performance_score: 100.0},
  %{name: "Best", performance_score: 50.0},
  %{name: "No score", performance_score: nil}
]
# Expected order after sorting: Best, Good, Bad, No score (nil at end)
```

#### **Strategie bez performance_score**
```elixir
# Test case: strategies with nil performance_score
# Expected: appear at end of sorted list
```

#### **Równe performance_score**
```elixir
# Test case: strategies with same performance_score
# Expected: stable sort (maintain original order or sort by other criteria)
```

## 4. Test Data Factory

### 4.1 Testowe symulacje i strategie
```elixir
defmodule TestData.Statistics do
  def create_strategy_with_simulations(attempt_counts) do
    # Create a strategy and multiple successful simulations
    strategy = insert_strategy()
    Enum.each(attempt_counts, fn attempts ->
      insert_successful_simulation(strategy.id, attempts)
    end)
    strategy
  end

  def sample_attempt_counts do
    # Odd number for median testing
    [100, 125, 150, 175, 200]
    # Sorted: [100, 125, 150, 175, 200]
    # Median: 150.0
  end

  def even_attempt_counts do
    # Even number for median testing
    [100, 125, 150, 175]
    # Sorted: [100, 125, 150, 175]
    # Median: 137.5 (average of 125 and 150)
  end

  def single_attempt_count do
    [42]
    # Median: 42.0
  end

  def large_attempt_counts do
    Enum.to_list(1..1000)
    # Median: 500.5
  end
end
```

### 4.2 Edge case data
```elixir
defmodule EdgeCaseData.Statistics do
  def extreme_values do
    [1, 1_000_000, 500_000]
  end

  def floating_point_values do
    [1.5, 2.5, 3.5, 4.5]
    # Median: 3.0 (average of 2.5 and 3.5)
  end

  def duplicate_values do
    [100, 100, 100, 200, 200]
    # Median: 100.0
  end

  def unsorted_extreme do
    [999, 1, 500, 1000, 2, 750]
    # Should be sorted internally
  end
end
```

## 5. Struktura testów

### 5.1 Organizacja plików
```
test/numbers_evolution/
├── simulations/
│   ├── statistics_test.exs           # calculate_median, update_strategy_performance
│   └── ranking_integration_test.exs  # pełne przepływy rankingów
├── strategies/
│   └── strategy_performance_test.exs # performance_changeset, sortowanie
```

### 5.2 Setup testowy
```elixir
defmodule NumbersEvolution.StatisticsTest do
  use NumbersEvolution.DataCase, async: true

  alias NumbersEvolution.Simulations
  alias NumbersEvolution.Strategies.Strategy

  # Helper to test private functions
  def test_calculate_median(list) do
    # Since calculate_median is private, we test it through update_strategy_performance
    # or make it testable in test environment
    Simulations.calculate_median(list)
  end

  # Helper to create test data
  def create_test_strategy_with_simulations(attempt_counts) do
    TestData.Statistics.create_strategy_with_simulations(attempt_counts)
  end
end
```

## 6. Strategie testowania

### 6.1 Testowanie funkcji prywatnych
```elixir
# Approach: Test through public API
test "calculate_median through update_strategy_performance" do
  strategy = create_test_strategy_with_simulations([100, 200, 150])
  # Trigger update_strategy_performance
  updated_strategy = Repo.get(Strategy, strategy.id)
  assert updated_strategy.performance_score == 150.0
end
```

### 6.2 Testowanie dokładności obliczeń
```elixir
# Use property-based testing for mathematical correctness
property "median calculation is correct" do
  check all list <- list_of(positive_integer(), min_length: 1, max_length: 100) do
    median = calculate_median(Enum.sort(list))
    assert median_correct?(list, median)
  end
end
```

### 6.3 Testowanie wydajności
```elixir
test "median calculation performance" do
  large_list = Enum.to_list(1..10_000)

  {time, result} = :timer.tc(fn ->
    calculate_median(large_list)
  end)

  # Should complete in reasonable time (< 100ms)
  assert time < 100_000
  assert result == 5000.5
end
```

## 7. Priorytety testowania

### Wysoki priorytet (krytyczne dla biznesu)
1. **`calculate_median/1`** - błędne obliczenia = błędne rankingi
2. **`update_strategy_performance/1`** - synchronizacja wyników z UI
3. **Sortowanie strategii** - kluczowa funkcjonalność rankingów
4. **Dokładność mediany** - statystyczna poprawność

### Średni priorytet (integralność danych)
5. **Performance changeset** - walidacja danych
6. **Edge cases mediany** - puste listy, duplikaty
7. **Aktualizacja po symulacjach** - trigger performance updates

### Niski priorytet (optymalizacja)
8. **Wydajność obliczeń** - dla dużych zbiorów
9. **Precyzja floating point** - dokładność obliczeń
10. **Memory usage** - zużycie pamięci przy dużych listach

## 8. Metryki sukcesu testów

- **Dokładność:** Wszystkie obliczenia mediany zweryfikowane matematycznie
- **Pokrycie:** 100% dla funkcji `calculate_median/1` i `update_strategy_performance/1`
- **Performance:** Obliczenia mediany dla 1000 elementów w <10ms
- **Data integrity:** Performance scores zawsze synchronizowane z wynikami symulacji
- **Edge cases:** Wszystkie przypadki graniczne pokryte

## 9. Uruchamianie testów

```bash
# Wszystkie testy statystyk
mix test test/numbers_evolution/simulations/statistics_test.exs
mix test test/numbers_evolution/strategies/strategy_performance_test.exs

# Testy dokładności obliczeń
mix test --only "median"

# Testy wydajności
mix test --only "performance"

# Z pokryciem
mix test --cover test/numbers_evolution/simulations/statistics_test.exs
```

## 10. Integration z CI/CD

- **Unit tests** - wszystkie testy statystyk uruchamiane zawsze
- **Property tests** - dla matematycznej dokładności (opcjonalnie)
- **Performance tests** - monitoring czasu wykonania
- **Accuracy tests** - weryfikacja poprawności obliczeń

---

## Podsumowanie wymagań

**Obecne pokrycie:** Brak dedykowanych testów dla statystyk i rankingów  
**Wymagane pokrycie:** 95%+ dla wszystkich funkcji obliczeniowych  
**Krytyczne braki:** `calculate_median/1`, aktualizacja performance score  
**Szacowany czas:** 3-4 godzin implementacji  
**Wpływ na biznes:** Błędne rankingi wpływają na zaufanie użytkowników
