# Test Plan: Walidacja Reguł Strategii (StrategyRules)

## 1. Wprowadzenie

### Moduł docelowy
`NumbersEvolution.Strategies.StrategyRules` - embedded schema odpowiedzialne za walidację reguł strategii Eurojackpot.

### Dlaczego warto testować
- **Złożona logika walidacji changeset'ów** - wiele poziomów zagnieżdżonych walidacji
- **Krytyczna dla integralności danych** - nieprawidłowe reguły mogą prowadzić do błędnych strategii
- **Niestandardowe walidatory** - `validate_ratio_sum/3`, `validate_weights_sum/1`, `validate_number_range/3`
- **Dokładne wymagania matematyczne** - wagi muszą sumować się do 1.0, proporcje muszą być spójne
- **Embedded schemas** - złożona struktura z wielopoziomowymi relacjami

### Zakres testowania
- **Unit tests** - wszystkie publiczne i prywatne funkcje walidacyjne
- **Schema validation** - struktura embedded schema
- **Edge cases** - graniczne wartości, nieprawidłowe dane wejściowe
- **Error handling** - odpowiednie komunikaty błędów

## 2. Funkcje do przetestowania

### 2.1 Główny changeset: `changeset/2`
**Cel:** Walidacja kompletnej struktury reguł strategii

### 2.2 Main numbers changeset: `main_numbers_changeset/2`
**Cel:** Walidacja reguł dla liczb głównych (1-50)

### 2.3 Euro numbers changeset: `euro_numbers_changeset/2`
**Cel:** Walidacja reguł dla liczb Euro (1-12)

### 2.4 Weights changesets: `main_weights_changeset/2`, `euro_weights_changeset/2`
**Cel:** Walidacja wag z wymaganą sumą 1.0

### 2.5 Niestandardowe walidatory:
- `validate_ratio_sum/3` - walidacja proporcji [even, odd] i [low, high]
- `validate_number_range/3` - walidacja zakresów liczb
- `validate_weights_sum/1` - walidacja sumy wag z tolerancją 0.001

## 3. Szczegółowe scenariusze testowe

### 3.1 Testy `changeset/2`

#### **Prawidłowe dane wejściowe**
```elixir
# Test case: valid complete strategy rules
attrs = %{
  main_numbers: %{
    ratio_even_odd: [2, 3],      # 2 parzyste + 3 nieparzyste = 5
    ratio_low_high: [3, 2],      # 3 z 1-25 + 2 z 26-50 = 5
    preferred_hot: [7, 19, 23],
    preferred_cold: [11, 34],
    weights: %{
      hot: 0.5,
      cold: 0.2,
      random: 0.3
    }
  },
  euro_numbers: %{
    ratio_even_odd: [1, 1],      # 1 parzysta + 1 nieparzysta = 2
    preferred: [3, 7],
    weights: %{
      hot: 0.6,
      random: 0.4
    }
  }
}
# Expected: valid changeset, no errors
```

#### **Brak wymaganych pól**
```elixir
# Test case: missing main_numbers
attrs = %{euro_numbers: %{...}}
# Expected: error "main_numbers is required"

# Test case: missing euro_numbers
attrs = %{main_numbers: %{...}}
# Expected: error "euro_numbers is required"
```

#### **Nieprawidłowa struktura**
```elixir
# Test case: invalid nested structure
attrs = %{
  main_numbers: "invalid_string",
  euro_numbers: %{...}
}
# Expected: validation errors for embedded fields
```

### 3.2 Testy proporcji (`validate_ratio_sum/3`)

#### **Prawidłowe proporcje**
```elixir
# Test case: valid ratio_even_odd for main numbers [2, 3]
# Expected: no errors (2+3=5)

# Test case: valid ratio_even_odd for euro numbers [1, 1]
# Expected: no errors (1+1=2)

# Test case: valid ratio_low_high [3, 2]
# Expected: no errors (3+2=5)
```

#### **Nieprawidłowe proporcje**
```elixir
# Test case: invalid sum for main numbers [3, 3]
# Expected: error "must sum to 5, got 6"

# Test case: invalid sum for euro numbers [2, 1]
# Expected: error "must sum to 2, got 3"

# Test case: negative values [-1, 6]
# Expected: error "must be a list of two non-negative integers"

# Test case: non-integer values [2.5, 2.5]
# Expected: error "must be a list of two non-negative integers"

# Test case: wrong format "2,3"
# Expected: error "must be a list of two non-negative integers"
```

#### **Edge cases proporcji**
```elixir
# Test case: all even [5, 0]
# Expected: valid

# Test case: all odd [0, 5]
# Expected: valid

# Test case: empty ratio []
# Expected: error

# Test case: too many elements [1, 2, 2]
# Expected: error
```

### 3.3 Testy wag (`validate_weights_sum/1`)

#### **Prawidłowe wagi**
```elixir
# Test case: exact sum 1.0
weights = %{hot: 0.5, cold: 0.3, random: 0.2}
# Expected: valid

# Test case: sum within tolerance (1.0005)
weights = %{hot: 0.333, cold: 0.333, random: 0.3345}
# Expected: valid (tolerance ±0.001)
```

#### **Nieprawidłowe wagi**
```elixir
# Test case: sum too high (1.1)
weights = %{hot: 0.5, cold: 0.4, random: 0.2}
# Expected: error "must sum to 1.0 (±0.001 tolerance), got 1.1"

# Test case: sum too low (0.9)
weights = %{hot: 0.3, cold: 0.3, random: 0.3}
# Expected: error "must sum to 1.0 (±0.001 tolerance), got 0.9"

# Test case: negative weights
weights = %{hot: -0.1, cold: 0.6, random: 0.5}
# Expected: error "must be greater than or equal to 0.0"

# Test case: weights > 1.0
weights = %{hot: 1.5, cold: 0.3, random: 0.2}
# Expected: error "must be less than or equal to 1.0"
```

#### **Edge cases wag**
```elixir
# Test case: all weight on one type
weights = %{hot: 1.0, cold: 0.0, random: 0.0}
# Expected: valid

# Test case: zero weights (invalid for business logic)
weights = %{hot: 0.0, cold: 0.0, random: 0.0}
# Expected: error "must sum to 1.0"

# Test case: very small precision values
weights = %{hot: 0.333333333, cold: 0.333333333, random: 0.333333334}
# Expected: valid (within tolerance)
```

### 3.4 Testy zakresów liczb (`validate_number_range/3`)

#### **Prawidłowe zakresy**
```elixir
# Test case: main numbers in 1-50 range
preferred_hot = [7, 19, 23, 42]
# Expected: valid

# Test case: euro numbers in 1-12 range
preferred = [3, 7, 11]
# Expected: valid

# Test case: empty list
preferred_hot = []
# Expected: valid
```

#### **Nieprawidłowe zakresy**
```elixir
# Test case: main numbers out of range
preferred_hot = [0, 51, 100]
# Expected: error "all numbers must be in range 1..50"

# Test case: euro numbers out of range
preferred = [0, 13, 25]
# Expected: error "all numbers must be in range 1..12"

# Test case: mixed valid/invalid
preferred_hot = [5, 25, 60]
# Expected: error "all numbers must be in range 1..50"
```

#### **Edge cases zakresów**
```elixir
# Test case: boundary values
preferred_hot = [1, 50]
# Expected: valid

# Test case: duplicates (allowed)
preferred_hot = [7, 7, 19, 19]
# Expected: valid

# Test case: non-integer values
preferred_hot = [7.5, 19]
# Expected: error "all numbers must be in range 1..50"

# Test case: non-list input
preferred_hot = "invalid"
# Expected: error "all numbers must be in range 1..50"
```

### 3.5 Testy changeset'ów zagnieżdżonych

#### **Main numbers changeset**
```elixir
# Test case: missing required fields
attrs = %{preferred_hot: [1, 2, 3]}
# Expected: errors for ratio_even_odd, ratio_low_high, weights

# Test case: invalid ratios with valid weights
attrs = %{
  ratio_even_odd: [3, 3],  # sum = 6, should be 5
  ratio_low_high: [3, 2],  # valid
  weights: %{hot: 0.5, cold: 0.3, random: 0.2}  # valid
}
# Expected: error only for ratio_even_odd
```

#### **Euro numbers changeset**
```elixir
# Test case: missing ratio_even_odd
attrs = %{
  preferred: [1, 2],
  weights: %{hot: 0.6, random: 0.4}
}
# Expected: error "ratio_even_odd is required"

# Test case: invalid euro ratio
attrs = %{
  ratio_even_odd: [3, 0],  # sum = 3, should be 2
  preferred: [1, 2],
  weights: %{hot: 0.6, random: 0.4}
}
# Expected: error "must sum to 2, got 3"
```

## 4. Test Data Factory

### 4.1 Valid Test Data
```elixir
defmodule TestData do
  def valid_strategy_rules do
    %{
      main_numbers: %{
        ratio_even_odd: [2, 3],
        ratio_low_high: [3, 2],
        preferred_hot: [7, 19, 23],
        preferred_cold: [11, 34],
        weights: %{hot: 0.5, cold: 0.2, random: 0.3}
      },
      euro_numbers: %{
        ratio_even_odd: [1, 1],
        preferred: [3, 7],
        weights: %{hot: 0.6, random: 0.4}
      }
    }
  end

  def valid_main_numbers do
    %{
      ratio_even_odd: [2, 3],
      ratio_low_high: [3, 2],
      preferred_hot: [7, 19, 23],
      preferred_cold: [11, 34],
      weights: %{hot: 0.5, cold: 0.2, random: 0.3}
    }
  end

  def valid_euro_numbers do
    %{
      ratio_even_odd: [1, 1],
      preferred: [3, 7],
      weights: %{hot: 0.6, random: 0.4}
    }
  end
end
```

### 4.2 Invalid Test Data
```elixir
defmodule InvalidTestData do
  def invalid_weights_sum do
    %{hot: 0.5, cold: 0.6, random: 0.2}  # sum = 1.3
  end

  def invalid_ratios do
    %{ratio_even_odd: [3, 3], ratio_low_high: [4, 2]}  # sums = 6, 6 instead of 5, 5
  end

  def out_of_range_numbers do
    %{preferred_hot: [0, 51, 100]}
  end
end
```

## 5. Struktura testów

### 5.1 Organizacja plików
```
test/numbers_evolution/strategies/
├── strategy_rules_test.exs           # Główny plik testowy
├── strategy_rules/
│   ├── changeset_test.exs           # Testy changeset/2
│   ├── ratio_validation_test.exs    # Testy validate_ratio_sum
│   ├── weights_validation_test.exs  # Testy validate_weights_sum
│   └── range_validation_test.exs    # Testy validate_number_range
```

### 5.2 Setup testowy
```elixir
defmodule NumbersEvolution.Strategies.StrategyRulesTest do
  use ExUnit.Case, async: true
  alias NumbersEvolution.Strategies.StrategyRules

  # Helper function to create empty struct for testing
  defp empty_rules do
    %StrategyRules{}
  end

  # Helper to assert changeset errors
  defp assert_changeset_error(changeset, field, message) do
    assert %{^field => [^message]} = errors_on(changeset)
  end
end
```

## 6. Priorytety testowania

### Wysoki priorytet (krytyczne dla bezpieczeństwa)
1. **Walidacja wag** - nieprawidłowe wagi mogą prowadzić do nieskończonych pętli
2. **Walidacja proporcji** - nieprawidłowe proporcje generują błędne strategie
3. **Walidacja zakresów** - liczby poza zakresem powodują runtime errors

### Średni priorytet (poprawność biznesowa)
4. **Kompletność required pól** - zapewnia spójność danych
5. **Embedded changeset relations** - poprawna struktura zagnieżdżona

### Niski priorytet (UX)
6. **Komunikaty błędów** - czytelność dla użytkowników
7. **Edge cases** - rzadkie scenariusze

## 7. Metryki sukcesu testów

- **Pokrycie kodu:** >95%
- **Wszystkie edge cases** pokryte
- **Performance:** każdy test <100ms
- **Maintainability:** czytelne nazwy testów, dobre opisy

## 8. Uruchamianie testów

```bash
# Wszystkie testy StrategyRules
mix test test/numbers_evolution/strategies/strategy_rules_test.exs

# Z pokryciem
mix test --cover test/numbers_evolution/strategies/strategy_rules_test.exs

# Tylko konkretne testy
mix test test/numbers_evolution/strategies/strategy_rules_test.exs --only "validate_weights_sum"
```

## 9. Integration z CI/CD

- Testy uruchamiane automatycznie przy każdym push/PR
- Wymagane przejście wszystkich testów przed merge
- Raporty pokrycia kodu generowane automatycznie
- Alerty przy spadku pokrycia poniżej 90%
