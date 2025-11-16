# Przykładowe Strategie - Numbers Evolution

## Przegląd

Dokument zawiera przykładowe strategie do testowania w aplikacji Numbers Evolution. Każda strategia ma określone cele, reguły i spodziewane zachowanie.

## 1. Strategia "Tylko Nieparzyste"

**Cel**: Pomin połowę liczb (wszystkie parzyste), skupiamy się tylko na nieparzystych.

**Reguły (JSON)**:
```json
{
  "main_numbers": {
    "blacklist": [2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50],
    "ratio_even_odd": [0, 5],
    "ratio_low_high": [3, 2],
    "preferred_hot": [],
    "preferred_cold": [],
    "weights": {
      "hot": 0.5,
      "cold": 0.0,
      "random": 0.5
    },
    "max_per_decade": 5,
    "max_consecutive": 5
  },
  "euro_numbers": {
    "blacklist": [],
    "ratio_even_odd": [1, 1],
    "preferred": [],
    "weights": {
      "hot": 0.5,
      "random": 0.5
    }
  }
}
```

**Charakterystyka**:
- Wszystkie 5 liczb głównych nieparzyste (1, 3, 5, 7, 9, 11, 13, ...)
- 25 liczb parzystych na blacklist
- Pozostaje 25 liczb do wyboru
- Równe wagi hot i random (50/50)
- Brak ograniczeń dystrybucji

**AI Prompt**: 
```
Pomin połowę liczb od 1 do 50 (wszystkie parzyste). Skupimy się tylko na nieparzystych. Dla euro wszystkie liczby dostępne.
```

---

## 2. Strategia "2 Nieparzyste, 3 Parzyste"

**Cel**: Precyzyjne określenie ratio parzystości - 2 nieparzyste, 3 parzyste.

**Reguły (JSON)**:
```json
{
  "main_numbers": {
    "blacklist": [],
    "ratio_even_odd": [3, 2],
    "ratio_low_high": [2, 3],
    "preferred_hot": [],
    "preferred_cold": [],
    "weights": {
      "hot": 0.5,
      "cold": 0.2,
      "random": 0.3
    },
    "max_per_decade": 5,
    "max_consecutive": 5
  },
  "euro_numbers": {
    "blacklist": [],
    "ratio_even_odd": [1, 1],
    "preferred": [],
    "weights": {
      "hot": 0.5,
      "random": 0.5
    }
  }
}
```

**Charakterystyka**:
- Dokładnie 3 parzyste i 2 nieparzyste
- 2 niskie (1-25), 3 wysokie (26-50)
- Wagi: 50% hot, 20% cold, 30% random
- Pełna pula liczb (brak blacklist)
- Brak ograniczeń dystrybucji

**AI Prompt**: 
```
Dwie liczby główne mają być nieparzyste, reszta parzyste. Wagi: 50% hot, 30% random, 20% cold.
```

---

## 3. Strategia "Max 2 w Dziesiątce"

**Cel**: Nie mogą być wszystkie liczby przy sobie - maksymalnie 2 w jednej dziesiątce, bez kolejnych.

**Reguły (JSON)**:
```json
{
  "main_numbers": {
    "blacklist": [],
    "ratio_even_odd": [2, 3],
    "ratio_low_high": [3, 2],
    "preferred_hot": [7, 15, 23, 34, 42],
    "preferred_cold": [],
    "weights": {
      "hot": 0.6,
      "cold": 0.2,
      "random": 0.2
    },
    "max_per_decade": 2,
    "max_consecutive": 1
  },
  "euro_numbers": {
    "blacklist": [],
    "ratio_even_odd": [1, 1],
    "preferred": [3, 9],
    "weights": {
      "hot": 0.6,
      "random": 0.4
    }
  }
}
```

**Charakterystyka**:
- **KLUCZOWE**: max 2 liczby w każdej dziesiątce (1-10, 11-20, 21-30, 31-40, 41-50)
- **KLUCZOWE**: max 1 kolejna liczba (brak 7,8 lub 23,24,25)
- 2 parzyste, 3 nieparzyste
- 3 niskie, 2 wysokie
- Preferowane hot numbers: 7, 15, 23, 34, 42
- Wysokie wagi na hot (60%)

**AI Prompt**: 
```
Maksymalnie 2 liczby w jednej dziesiątce i nie mogą być kolejne (np. 7,8). Preferuj hot numbers z ostatnich 16 losowań.
```

**Walidacja dystrybucji**:
- ✅ Prawidłowe: `[7, 15, 23, 34, 42]` - max 2 w dziesiątce, brak kolejnych
- ✅ Prawidłowe: `[3, 12, 21, 35, 49]` - max 2 w dziesiątce, brak kolejnych
- ❌ Nieprawidłowe: `[1, 2, 3, 15, 23]` - 3 liczby w dziesiątce 1-10
- ❌ Nieprawidłowe: `[7, 8, 15, 23, 34]` - 7,8 są kolejne
- ❌ Nieprawidłowe: `[21, 22, 23, 34, 45]` - 21,22,23 to 3 kolejne

---

## 4. Strategia "Balans Hot/Cold"

**Cel**: Zbalansowane podejście z równymi wagami hot i random, mała waga cold.

**Reguły (JSON)**:
```json
{
  "main_numbers": {
    "blacklist": [],
    "ratio_even_odd": [3, 2],
    "ratio_low_high": [3, 2],
    "preferred_hot": [7, 23, 34],
    "preferred_cold": [1, 50],
    "weights": {
      "hot": 0.4,
      "cold": 0.2,
      "random": 0.4
    },
    "max_per_decade": 5,
    "max_consecutive": 5
  },
  "euro_numbers": {
    "blacklist": [],
    "ratio_even_odd": [1, 1],
    "preferred": [3, 9],
    "weights": {
      "hot": 0.5,
      "random": 0.5
    }
  }
}
```

**Charakterystyka**:
- Zbalansowane wagi: 40% hot, 40% random, 20% cold
- 3 parzyste, 2 nieparzyste
- 3 niskie, 2 wysokie
- Preferowane hot: 7, 23, 34
- Preferowane cold: 1, 50
- Brak ograniczeń dystrybucji

**AI Prompt**: 
```
Strategia balansująca hot i cold numbers z wagami 40% hot, 40% random, 20% cold. Ratio 3 parzyste/2 nieparzyste.
```

---

## 5. Strategia "Ekstremalna Hot"

**Cel**: Maksymalne skupienie na hot numbers z ostatnich losowań.

**Reguły (JSON)**:
```json
{
  "main_numbers": {
    "blacklist": [],
    "ratio_even_odd": [2, 3],
    "ratio_low_high": [2, 3],
    "preferred_hot": [7, 12, 18, 23, 28, 34, 39, 42, 47],
    "preferred_cold": [],
    "weights": {
      "hot": 0.8,
      "cold": 0.0,
      "random": 0.2
    },
    "max_per_decade": 5,
    "max_consecutive": 3
  },
  "euro_numbers": {
    "blacklist": [],
    "ratio_even_odd": [1, 1],
    "preferred": [3, 5, 7, 9, 11],
    "weights": {
      "hot": 0.9,
      "random": 0.1
    }
  }
}
```

**Charakterystyka**:
- **Ekstremalne wagi**: 80% hot, 0% cold, 20% random dla głównych
- 90% hot dla euro
- 9 preferowanych hot numbers głównych
- 5 preferowanych hot euro
- Dopuszcza max 3 kolejne liczby

**AI Prompt**: 
```
Strategia maksymalnie skupiona na hot numbers z ostatnich 32 losowań. Wagi: 80% hot, 20% random. Całkowicie ignoruj cold numbers.
```

---

## 6. Strategia "Przeciwny Trend"

**Cel**: Gra przeciwko trendowi - skupienie na cold numbers.

**Reguły (JSON)**:
```json
{
  "main_numbers": {
    "blacklist": [],
    "ratio_even_odd": [2, 3],
    "ratio_low_high": [3, 2],
    "preferred_hot": [],
    "preferred_cold": [1, 5, 13, 17, 25, 31, 41, 45, 50],
    "weights": {
      "hot": 0.1,
      "cold": 0.7,
      "random": 0.2
    },
    "max_per_decade": 5,
    "max_consecutive": 5
  },
  "euro_numbers": {
    "blacklist": [],
    "ratio_even_odd": [1, 1],
    "preferred": [1, 2, 12],
    "weights": {
      "hot": 0.2,
      "random": 0.8
    }
  }
}
```

**Charakterystyka**:
- **Odwrotna logika**: 70% cold, tylko 10% hot
- Zakłada że "zaniedbane" liczby mają większą szansę
- 9 preferowanych cold numbers
- Dla euro głównie random (80%)

**AI Prompt**: 
```
Strategia przeciwna do hot numbers - skupiamy się na liczbach cold (rzadko wypadających) z ostatnich 64 losowań. Wagi: 70% cold, 20% random, 10% hot.
```

---

## 7. Strategia "Pełna Losowość"

**Cel**: Czysto losowa strategia bez preferencji - kontrola/baseline.

**Reguły (JSON)**:
```json
{
  "main_numbers": {
    "blacklist": [],
    "ratio_even_odd": [2, 3],
    "ratio_low_high": [2, 3],
    "preferred_hot": [],
    "preferred_cold": [],
    "weights": {
      "hot": 0.0,
      "cold": 0.0,
      "random": 1.0
    },
    "max_per_decade": 5,
    "max_consecutive": 5
  },
  "euro_numbers": {
    "blacklist": [],
    "ratio_even_odd": [1, 1],
    "preferred": [],
    "weights": {
      "hot": 0.0,
      "random": 1.0
    }
  }
}
```

**Charakterystyka**:
- 100% random dla wszystkich liczb
- Brak preferowanych liczb
- Brak blacklist
- Baseline do porównania z innymi strategiami
- Tylko ratio określa parzyste/nieparzyste i low/high

**AI Prompt**: 
```
Całkowicie losowa strategia bez żadnych preferencji. 100% random dla wszystkich liczb. Użyj jako baseline do porównania.
```

---

## Implementacja w Seeds

Aby dodać te strategie do seeds (`priv/repo/seeds.exs`):

```elixir
# Utwórz testowego użytkownika
user = Repo.get_by(User, email: "test@example.com") || 
  Repo.insert!(%User{
    email: "test@example.com",
    hashed_password: Bcrypt.hash_pwd_salt("Password123!")
  })

# Strategia 1: Tylko Nieparzyste
Repo.insert!(%Strategy{
  user_id: user.id,
  name: "Tylko Nieparzyste",
  type: :manual,
  description: "Pomija wszystkie parzyste liczby główne (1-50)",
  rules: %{
    "main_numbers" => %{
      "blacklist" => [2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50],
      "ratio_even_odd" => [0, 5],
      "ratio_low_high" => [3, 2],
      "weights" => %{"hot" => 0.5, "cold" => 0.0, "random" => 0.5},
      "max_per_decade" => 5,
      "max_consecutive" => 5
    },
    "euro_numbers" => %{
      "blacklist" => [],
      "ratio_even_odd" => [1, 1],
      "weights" => %{"hot" => 0.5, "random" => 0.5}
    }
  }
})

# Strategia 2: 2 Nieparzyste, 3 Parzyste
Repo.insert!(%Strategy{
  user_id: user.id,
  name: "2 Nieparzyste, 3 Parzyste",
  type: :manual,
  description: "Precyzyjne ratio: 2 nieparzyste, 3 parzyste",
  rules: %{
    "main_numbers" => %{
      "blacklist" => [],
      "ratio_even_odd" => [3, 2],
      "ratio_low_high" => [2, 3],
      "weights" => %{"hot" => 0.5, "cold" => 0.2, "random" => 0.3},
      "max_per_decade" => 5,
      "max_consecutive" => 5
    },
    "euro_numbers" => %{
      "blacklist" => [],
      "ratio_even_odd" => [1, 1],
      "weights" => %{"hot" => 0.5, "random" => 0.5}
    }
  }
})

# Strategia 3: Max 2 w Dziesiątce
Repo.insert!(%Strategy{
  user_id: user.id,
  name: "Max 2 w Dziesiątce",
  type: :manual,
  description: "Max 2 liczby w dziesiątce, brak kolejnych",
  rules: %{
    "main_numbers" => %{
      "blacklist" => [],
      "ratio_even_odd" => [2, 3],
      "ratio_low_high" => [3, 2],
      "preferred_hot" => [7, 15, 23, 34, 42],
      "weights" => %{"hot" => 0.6, "cold" => 0.2, "random" => 0.2},
      "max_per_decade" => 2,
      "max_consecutive" => 1
    },
    "euro_numbers" => %{
      "blacklist" => [],
      "ratio_even_odd" => [1, 1],
      "preferred" => [3, 9],
      "weights" => %{"hot" => 0.6, "random" => 0.4}
    }
  }
})

# Dodaj pozostałe strategie...
```

---

## Testowanie Strategii

### Test scenariusz 1: Tworzenie manualnej strategii
1. Zaloguj się do aplikacji
2. Przejdź do sekcji "Strategie"
3. Kliknij "Nowa strategia"
4. Wybierz tab "Manualna"
5. Wypełnij formularz zgodnie z jedną ze strategii powyżej
6. Zapisz
7. Sprawdź czy strategia pojawia się na liście

### Test scenariusz 2: Generowanie przez AI
1. Kliknij "Nowa strategia"
2. Wybierz tab "AI"
3. Użyj jednego z przykładowych promptów
4. Kliknij "Generuj strategię"
5. Sprawdź wygenerowane reguły
6. Zapisz strategię

### Test scenariusz 3: Symulacja strategii
1. Przejdź do sekcji "Symulacje"
2. Wybierz strategię "Max 2 w Dziesiątce"
3. Wybierz target draw
4. Uruchom symulację
5. Sprawdź czy wygenerowane liczby spełniają ograniczenia:
   - Max 2 w jednej dziesiątce
   - Brak kolejnych liczb

---

## Metryki Sukcesu

Dla każdej strategii monitoruj:
- **Performance Score**: Mediana liczby prób
- **Success Rate**: % udanych symulacji
- **Average Time**: Średni czas trwania symulacji
- **Consistency**: Odchylenie standardowe performance score

**Oczekiwane rezultaty**:
- Strategie z mniejszym blacklist: lepszy performance score
- Strategie z ograniczeniami dystrybucji: gorszy performance score, ale ciekawsze zestawy
- Pełna losowość: baseline do porównania

