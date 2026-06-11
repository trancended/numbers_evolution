# Plan implementacji: gra Lotto obok Eurojackpot

## 1. Przegląd

Aplikacja obsługuje dziś wyłącznie Eurojackpot (5 z 50 + 2 z 12), mimo że schemat `draws`
dopuszcza `game_type` `"lotto"` i `"multi_multi"`. Celem jest dodanie polskiego **Lotto**
(6 z 49, bez liczb dodatkowych) jako pełnoprawnej gry do wyboru obok Eurojackpot:

- import wyników Lotto (Lottoland API ma endpoint `polishLotto` — zweryfikowano, zwraca
  `"numbers": [6 liczb]`, bez liczb dodatkowych; dodatkowo pole `polishLottoPlus`),
- przechowywanie i walidacja losowań Lotto,
- generowanie kuponów 6 z 49,
- symulacje przeciwko losowaniom Lotto (w tym tryby VIP1/VIP2),
- wybór gry w UI: formularz symulacji, generator kuponów, panel admina.

## 2. Zasady gry i tiery nagród

| Gra | Liczby główne | Liczby dodatkowe | Pełna pula |
|---|---|---|---|
| Eurojackpot | 5 z 1–50 | 2 z 1–12 (euro) | C(50,5)·C(12,2) = 139 838 160 |
| Lotto | 6 z 1–49 | brak | C(49,6) = 13 983 816 |

Tiery nagród Lotto (jackpot = tier 1, spójnie z istniejącą logiką `tier 1 ⇒ stop symulacji`):

| Tier | Trafienia | Nazwa |
|---|---|---|
| 1 | 6 | szóstka |
| 2 | 5 | piątka |
| 3 | 4 | czwórka |
| 4 | 3 | trójka |

Eurojackpot zachowuje dotychczasowe 12 tierów `{main, euro}`.

## 3. Architektura: moduł `NumbersEvolution.Games`

Jedyne źródło prawdy o konfiguracji gier — nowy moduł `lib/numbers_evolution/games.ex`:

```elixir
%{
  id: "lotto",
  label: "Lotto",
  main: %{count: 6, min: 1, max: 49, low_max: 25},
  bonus: %{count: 0, min: 0, max: 0},        # eurojackpot: count: 2, min: 1, max: 12
  prize_tiers: %{{6, 0} => 1, {5, 0} => 2, {4, 0} => 3, {3, 0} => 4},
  vip: %{pool_main: 25, pool_bonus: 0, parity_odd: 3, parity_even: 3},
  search_space: 13_983_816,
  import: %{api_path: "polishLotto"}
}
```

API modułu: `ids/0`, `get!/1`, `default_id/0` (`"eurojackpot"`), `label/1`,
`has_bonus?/1`, `select_options/0` (do `<select>` w UI).

Wszystkie stałe 5/50/2/12/25 rozsiane po kodzie zostają zastąpione odczytem z tej
konfiguracji. `multi_multi` pozostaje w `@valid_game_types`, ale bez konfiguracji —
celowo poza zakresem (faza 3).

## 4. Decyzje projektowe

1. **Strategie pozostają wspólne dla obu gier** (bez kolumny `game_type` w `strategies`).
   Gra jest wybierana na poziomie symulacji/generowania kuponów (gra losowania docelowego).
   Per-grę strategie + osobne prompty AI to faza 2.
2. **Ratio z reguł strategii przy 6 liczbach Lotto**: reguły (`ratio_even_odd`,
   `ratio_low_high`) sumują się do 5 (kształt Eurojackpot). Dla Lotto traktujemy je jako
   **minima** — 6. liczba jest nieograniczona (walidacja `>=` zamiast `==`). Dzięki temu
   istniejące strategie działają dla obu gier bez migracji danych.
3. **Podział low/high dla Lotto**: low = 1–25, high = 26–49 (zachowujemy próg 25
   z Eurojackpot; asymetria 25/24 jest pomijalna).
4. **VIP1 dla Lotto**: pula = `ceil(49/2) = 25` liczb głównych (zaokrąglenie w górę
   utrzymuje sensowną skuteczność walidacji „pula zawiera liczby docelowe”; dla
   Eurojackpot wzór daje dotychczasowe 25 i 6), parzystość **3 nieparzyste + 3 parzyste**
   (analogia do 2+3 przy 5 liczbach), max 2 liczby na dekadę (dekady 1–10 … 41–49).
5. **VIP2 / auto-blacklist dla Lotto**: domyślny rozmiar blacklisty = `floor(49/2) = 24`
   liczb głównych (Eurojackpot: 25/6 — bez zmian), liczby dodatkowe: 0. Cap rozmiaru:
   `max - count` (Lotto: 43). Semantyka look-ahead (blacklist nigdy nie blokuje liczb
   docelowych) bez zmian — patrz notatka w `generate_auto_blacklist/4`.
6. **`euro_numbers` w losowaniach Lotto = `[]`** — zostajemy przy wspólnym embedzie
   `DrawNumbers` (JSONB), walidacja zależna od `game_type` rodzica. Bez migracji DB
   (indeks unikalny `(game_type, draw_date)` już istnieje).
7. **Lotto Plus pomijamy** (payload API je zawiera — ewentualna faza 3 jako osobny
   `game_type`).
8. **Strategie „Losowo pomiń połowę” (half-random)** dla Lotto: pula 25 z 49,
   3 nieparzyste + 3 parzyste, bez liczb dodatkowych.
9. **Analytics/ranking**: `Analytics` liczy redukcję przestrzeni względem pełnej puli —
   parametryzacja `search_space` per gra. Ranking score (lower = better) bez zmian
   koncepcyjnych; porównywanie score'ów między grami opisane jako ograniczenie (faza 3).

## 5. Zmiany per plik

### Backend — domena

| Plik | Zmiana |
|---|---|
| `lib/numbers_evolution/games.ex` | **NOWY** — konfiguracja gier (sekcja 3) |
| `lib/numbers_evolution/draws/draw_numbers.ex` | `changeset/3` z konfiguracją gry: main `count/min/max`, bonus `count` (dla Lotto wymagane `euro_numbers == []`, default `[]`) |
| `lib/numbers_evolution/draws/draw.ex` | przekazanie `game_type` do `cast_embed(:numbers, with: ...)` |
| `lib/numbers_evolution/draws/importer.ex` | `import_latest/1` (id gry), parser per gra: eurojackpot `numbers + euroNumbers`, lotto `numbers` (6); URL z `Games` |
| `lib/mix/tasks/import_draws.ex` | `mix import.draws [gra]` — bez argumentu importuje wszystkie gry z konfiguracją importu |
| `lib/numbers_evolution/strategies/generator.ex` | parametryzacja per gra: liczność/zakresy main+bonus, low/high, walidacja ratio (== dla EJ, >= dla Lotto), pule hot/cold/random, half-random, VIP1 (pula, parzystość, dekady), VIP2, `validate_vip_constraints/3`, `validate_strategy_constraints/4`; opcja `:game` (default eurojackpot) |
| `lib/numbers_evolution/simulations.ex` | gra z `target_draw.game_type` w `SimulationContext`; `tiers_for_matches` z `Games.prize_tiers`; VIP1 pool/VIP2 blacklist per gra (rozmiary, capy); `generate_auto_blacklist/5` (z grą); przekazanie `:game` do generatora |
| `lib/numbers_evolution/analytics.ex` | `search_space` per gra (jeśli funkcja przyjmuje kontekst symulacji/gry; inaczej default EJ + TODO faza 3) |
| `lib/numbers_evolution/draws.ex` | bez zmian logiki (filtry `game_type` już są); aktualizacja przykładów w dokumentacji |

### Web — UI

| Plik | Zmiana |
|---|---|
| `lib/numbers_evolution_web/live/simulations_live.ex` | assign `:selected_game` (default eurojackpot), event `"game_changed"`, `list_draws(game_type: gra)`, filtrowanie VIP per gra |
| `lib/numbers_evolution_web/components/simulation_components.ex` | select gry obok selectu losowania; kule euro renderowane warunkowo (`euro_numbers != []`) |
| `lib/numbers_evolution_web/live/generator_live.ex` + `generator_components.ex` | select gry; generowanie kuponów 6 z 49; wyświetlanie kuponu bez sekcji euro dla Lotto |
| `lib/numbers_evolution_web/live/admin_live.ex` | import + podgląd najnowszego losowania per gra (pętla po grach z importem) |
| `lib/numbers_evolution_web/controllers/coupon_controller.ex` | przekazanie `game_type` z parametru do generatora (dziś ignorowany przy generowaniu) |
| `lib/numbers_evolution_web/components/core_components.ex` | `number_ball` bez zmian; dokumentacja „Eurojackpot balls” → ogólna |

### Testy

| Plik | Zmiana |
|---|---|
| `test/numbers_evolution/draws/importer_test.exs` | przypadki Lotto (parsowanie 6 liczb, idempotencja) |
| `test/numbers_evolution/simulations/simulations_logic_test.exs` | tiery Lotto (6/5/4/3 trafień, 0–2 trafienia → brak tieru) |
| nowe/istniejące testy generatora | generowanie 6 z 49, brak euro, minima ratio, VIP1/VIP2 per gra |

## 6. Przepływ użytkownika po zmianie

1. **Admin** importuje wyniki Lotto (przycisk per gra lub `mix import.draws lotto`).
2. **Symulacje**: użytkownik wybiera grę (Eurojackpot / Lotto) → lista losowań filtruje
   się po grze → wybiera strategię i losowanie → silnik dobiera generator i tiery po
   `game_type` losowania docelowego.
3. **Generator kuponów**: wybór gry → kupony 5+2 albo 6 liczb.

## 7. Ryzyka i ograniczenia

- **Wspólne strategie**: ratio jako minima dla Lotto to kompromis — preferencje hot/cold,
  blacklisty i wagi działają w pełni, ratio tylko częściowo. Rozwiązanie docelowe w fazie 2.
- **Porównywalność score'ów** między grami (pule różnią się 10×) — ranking pozostaje
  globalny; oznaczyć w UI/dokumentacji.
- **API Lottoland** dla `polishLotto` nie zawiera pola walut/numerów euro — parser musi
  być tolerancyjny na dodatkowe pola (`polishLottoPlus` ignorujemy).
- Stare symulacje/zapisane opcje (`vip1_pool`, `vip2_blacklist`) są zawsze EJ — odczyt
  per gra musi pozostać kompatybilny (gra wynika z `target_draw`, więc bez migracji).

## 8. Fazy

- **Faza 1 (ten plan, implementowana teraz)**: konfiguracja gier, walidacja losowań,
  import Lotto, generator + symulacje + VIP per gra, wybór gry w UI, testy.
- **Faza 2**: `game_type` w strategiach, prompty AI (OpenRouter) per gra, reguły ratio
  natywne dla 6 liczb, statystyki hot/cold w UI per gra.
- **Faza 3**: Multi Multi i Lotto Plus, ranking/score per gra, wykresy porównawcze.
