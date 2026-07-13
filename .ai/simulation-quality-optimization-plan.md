# Plan profesjonalnych optymalizacji symulacji — Numbers Evolution

> Cel: sprawić, by symulacje strategii lotto były **bardziej użyteczne, wartościowe i jakościowe** —
> tzn. wiarygodne statystycznie, reprodukowalne, interpretowalne i porównywalne — a nie tylko
> szybsze. Dokument jest planem (co, dlaczego, gdzie w kodzie, w jakiej kolejności), nie implementacją.

Data: 2026-07-12 · Gałąź bazowa: `credofix` / `main`

---

## 0. Zasady nienaruszalne (kontekst projektu)

Poniższe decyzje są celowe i **nie wolno ich „naprawiać"** przy realizacji planu:

- **Look-ahead VIP1/VIP2 jest intencjonalny** — auto-blacklist/pula VIP nigdy nie blokuje liczb
  losowania docelowego. To symulacja typu „co by było, gdyby", a nie uczciwa gra. Każda nowa
  metryka musi to jawnie komunikować jako *bias*, nie ukrywać.
- **`performance_score` = mediana prób do jackpota, niżej = lepiej.** Nowe metryki dodajemy obok,
  nie zmieniając semantyki istniejącego pola bez migracji.
- **Bench jest bramką wydajności** (`bench/e2e_bench.exs`, `components_bench.exs`). Po każdej
  zmianie w hot-pathcie (`Generator`, `Simulations.run_simulation`, dedup) re-run i aktualizacja
  liczb w nagłówkach plików bench.
- **`mix precommit` to bramka jakości**: `format`, `credo --strict` (max zagnieżdżenie 2,
  złożoność cyklomatyczna 9), testy. Każdy nowy moduł musi ją przechodzić.
- **Import**: Eurojackpot udostępnia tylko najnowsze losowanie; Lotto ma pełne archiwum od 1957.
  Backtesting historyczny jest realny **głównie dla Lotto** (Eurojackpot ma ograniczoną historię
  w bazie — patrz Faza 4).

---

## 1. Diagnoza — dlaczego symulacje są dziś mało wartościowe

Uczciwa ocena obecnego stanu (`lib/numbers_evolution/simulations.ex`,
`strategies/generator.ex`, `analytics.ex`):

| # | Problem | Skutek dla wartości wyniku |
|---|---------|----------------------------|
| P1 | **Pojedynczy brute-force = estymator o gigantycznej wariancji.** „Liczba prób do jackpota" jest zmienną geometryczną — jeden przebieg to jeden losowy punkt. | Dwa uruchomienia tej samej strategii dają wyniki różniące się o rzędy wielkości. Ranking bywa szumem. |
| P2 | **Tryb standardowy praktycznie nigdy nie trafia jackpota** (Eurojackpot 1:139,8 mln). Symulacje kończą się `timeout`/`max_attempts_reached`, a score nasyca się na suficie `max_attempts`. | Strategie standardowe są nierozróżnialne — score = ~`max_attempts` dla wszystkich. |
| P3 | **Brak przedziałów ufności, wariancji, rozkładu.** Zapisujemy tylko `attempts_count` i mediana per-strategia. | Nie da się powiedzieć „strategia A jest istotnie lepsza od B". |
| P4 | **Zero modelu wartości pieniężnej.** `prize_tiers` są zliczane, ale nigdzie nie ma kwot wygranych, kosztu kuponu, EV ani ROI. | Użytkownik nie wie, czy strategia „opłaca się" — a to jest właściwe pytanie. |
| P5 | **Brak reprodukowalności.** Generator korzysta z globalnego `:rand` procesu; ziarno nie jest zapisywane (`grep` potwierdza brak `:rand.seed` w ścieżce generacji). | Nie da się odtworzyć ani zaudytować konkretnego przebiegu. |
| P6 | **Ryzyko skorelowanych strumieni RNG.** Każda runda spawnuje `thread_count` Tasków; niezależność strumieni `:rand` nie jest kontrolowana. | Subtelny bias Monte Carlo przy równoległości. |
| P7 | **Niedokładne liczenie prób.** Współdzielony licznik ETS + brutalne ubijanie Tasków (`Task.shutdown(:brutal_kill)`) → `attempts_count` może przekroczyć `max_attempts` i gubić inkrementacje tierów. | Metryka bazowa jest „mniej więcej", co podważa rygor. |
| P8 | **`prize_details` rośnie bez ograniczeń** dla tierów 1–5 (`Simulations.PrizeTiersTracker`). W małej przestrzeni VIP2 tier 5 (4+1) trafia często. | Zużycie pamięci i rozdmuchany JSONB w wyniku. |
| P9 | **Brak backtestingu.** Symulacja = 1 strategia × 1 losowanie docelowe. | Nie odpowiada na pytanie „jak strategia radziłaby sobie na wielu losowaniach historycznych". |
| P10 | **Słaba interpretowalność.** UI pokazuje surowe `attempts` i liczniki tierów bez baseline'u losowego i bez wyjaśnienia biasu look-ahead. | Wynik łatwo (błędnie) uznać za „przewagę" strategii. |

**Wniosek:** największą dźwignią wartości nie jest przyspieszenie brute-force, lecz **zmiana pytania**
— z „ile prób zajęło jednorazowe trafienie" na „jaki jest oszacowany, z przedziałem ufności,
per-próbę rozkład trafień, oczekiwana wartość i ROI tej strategii, i czy jest ona istotnie lepsza
od losowej".

---

## 2. Kierunki optymalizacji (tematy)

Każdy temat: *problem → propozycja → pliki → wpływ → nakład → ryzyko → kryteria akceptacji*.
Nakład: S ≤ 0,5 dnia, M ≈ 1–2 dni, L ≈ 3–5 dni.

### Temat A — Estymacja Monte Carlo zamiast pojedynczego brute-force *(największa wartość)*

- **Problem:** P1, P2. Jeden przebieg to jeden punkt zmiennej o ogromnej wariancji; tryb standardowy
  nie kończy się trafieniem.
- **Propozycja:** wprowadzić **tryb estymacyjny (Monte Carlo)**: zamiast losować „aż do jackpota",
  wykonaj *ustaloną* liczbę N prób i oszacuj **prawdopodobieństwo trafienia per-próbę dla każdego
  tieru** wraz z przedziałem ufności (Wilson score interval na proporcji binomialnej). Silnik już
  zlicza `prize_tiers` po N próbach — to jest gotowy licznik sukcesów; wystarczy nie zatrzymywać się
  na tierze 1 i policzyć rate = count / N.
  - Oczekiwana liczba prób do jackpota = `1 / p̂_jackpot` z CI wyprowadzonym z CI dla `p`.
  - Dla trybu standardowego, gdzie `p̂_jackpot` bywa 0 na N prób: szacuj **niższe tiery**
    (które trafiają) i podawaj **górne ograniczenie** na `p_jackpot` (reguła „3/N" dla zdarzeń zerowych),
    zamiast raportować bezwartościowy timeout.
- **Pliki:** `simulations.ex` (nowa gałąź trybu w `run_simulation`/`simulate_until_match`),
  nowy moduł `NumbersEvolution.Simulations.Estimator` (czysta funkcja: liczniki tierów + N →
  rates + CI + oczekiwane próby), `simulation_result.ex` (pola na rates/CI), `analytics.ex`
  (konsumpcja nowych pól).
- **Wpływ:** przekształca niewiarygodny pojedynczy pomiar w poprawny estymator z niepewnością;
  czyni tryb standardowy sensownym.
- **Nakład:** L · **Ryzyko:** średnie (nowa semantyka wyniku, migracja pól) ·
- **Akceptacja:** dla ustalonej strategii i N=1 mln, powtórzone przebiegi dają `p̂` w tym samym
  przedziale ufności; test własności: `p̂_tier` zbiega do wartości analitycznej dla prostej
  strategii losowej (porównanie z `Analytics.comb/2`).

### Temat B — Metryki wartości: EV, ROI, hit-rate, baseline losowy

- **Problem:** P4, P10.
- **Propozycja:** dodać **tabelę wypłat per gra** do `Games` (kwoty/średnie wygrane per tier lub
  konfigurowalne przez użytkownika, plus koszt kuponu). Policzyć:
  - **Expected Value / kupon** = Σ_tier ( p̂_tier × wypłata_tier ) − koszt_kuponu.
  - **ROI (%)**, **hit-rate per tier** (już blisko: `tiers_per_100k` w `analytics.ex`),
    **oczekiwany zwrot na 1000 zł stawki**.
  - **Baseline losowy**: te same metryki dla czystego losowania bez strategii — każda strategia
    prezentowana jako *delta względem losowego* (to neutralizuje złudzenie „strategia = przewaga").
- **Pliki:** `games.ex` (statyczna tabela wypłat + koszt), nowy `Analytics.value_metrics/2`,
  `ranking_components.ex` / `simulation_components.ex` (kolumny EV/ROI/Δbaseline).
- **Wpływ:** odpowiada na realne pytanie użytkownika („czy się opłaca") i uczciwie pokazuje,
  że przewagi zwykle nie ma.
- **Nakład:** M · **Ryzyko:** niskie (dane wypłat trzeba oznaczyć jako orientacyjne) ·
- **Akceptacja:** EV losowego kuponu Eurojackpot mieści się w znanym rzędzie wielkości ujemnego
  zwrotu; jednostkowe testy na `value_metrics` z zadanymi wypłatami.

### Temat C — Rygor statystyczny: przedziały ufności, rozkład, istotność

- **Problem:** P1, P3.
- **Propozycja:**
  - Zapisywać **rozkład** wyników wielokrotnych przebiegów (histogram / percentyle P10/P50/P90),
    nie tylko medianę.
  - Dla porównań strategii A vs B: **test istotności** różnicy proporcji trafień (dwustronny test
    z-proporcji lub bootstrap na `attempts`), z jasnym werdyktem „różnica istotna / w granicach szumu".
  - Rozszerzyć `performance_changeset` o `performance_ci_low/high` (bez zmiany semantyki mediany).
- **Pliki:** nowy `NumbersEvolution.Statistics` (Wilson CI, z-test, bootstrap, percentyle — czyste
  funkcje, łatwo testowalne), `analytics.ex`, `strategies/strategy.ex` (nowe pola opcjonalne).
- **Wpływ:** ranking przestaje być szumem; użytkownik widzi niepewność.
- **Nakład:** M · **Ryzyko:** niskie · **Akceptacja:** testy jednostkowe funkcji statystycznych
  względem wartości referencyjnych; ranking pokazuje CI.

### Temat D — Reprodukowalność i jakość RNG

- **Problem:** P5, P6.
- **Propozycja:**
  - **Ziarno per-symulacja**: generować i zapisywać `seed` w `options`; na starcie przebiegu
    `:rand.seed(:exsss, seed)`. Umożliwia dokładne odtworzenie i audyt.
  - **Niezależne strumienie per-Task**: użyć `:rand.jump/0` lub odrębnych podziaren dla każdego
    z `thread_count` Tasków, by strumienie były gwarantowanie nieskorelowane (poprawność Monte Carlo).
  - Uwaga: reprodukowalność jest *dokładna* tylko w trybie 1-wątkowym; przy równoległości zapisać
    wektor podziaren wszystkich Tasków, albo udostępnić „tryb reprodukowalny = 1 wątek".
- **Pliki:** `simulations.ex` (`run_simulation`, `process_simulation_attempts_parallel`),
  `generator.ex` (żadnych zmian logiki — tylko korzysta z zainicjowanego stanu `:rand`).
- **Wpływ:** wyniki stają się audytowalne i naukowo powtarzalne.
- **Nakład:** M · **Ryzyko:** średnie (interakcja z równoległością) ·
- **Akceptacja:** dwa przebiegi 1-wątkowe z tym samym seedem dają identyczny `final_draw` i liczniki
  tierów; dokumentacja ograniczeń trybu równoległego.

### Temat E — Backtesting / framework eksperymentów

- **Problem:** P9.
- **Propozycja:** wprowadzić **eksperyment**: jedna strategia uruchamiana przeciw **zbiorowi
  losowań** (np. wszystkie losowania Lotto z ostatnich N lat) w trybie estymacyjnym, z agregacją
  rozkładu wyników. Odpowiada na „jak strategia poradziłaby sobie historycznie" — realna wartość
  analityczna zamiast pojedynczego „co by było gdyby".
  - Reużyć istniejącą równoległość (`Task.Supervisor`) do rozproszenia po losowaniach.
  - Wynik: rozkład EV/hit-rate po losowaniach + robustność (odchylenie między losowaniami).
- **Pliki:** nowy kontekst `NumbersEvolution.Experiments` (schemat + orchestracja), reużycie
  `Draws.list_draws/1`, `Simulations.Estimator`; nowy widok/LiveView lub rozszerzenie
  `simulations_live.ex`.
- **Wpływ:** największy skok „użyteczności" — od zabawki do narzędzia analitycznego.
- **Nakład:** L · **Ryzyko:** średnie (nowy model danych, wolumen obliczeń) ·
- **Akceptacja:** backtest strategii losowej na Lotto daje EV/ROI zgodne z teorią w granicach CI;
  agregacja stabilna między uruchomieniami.

### Temat F — Model danych i persystencja wyników

- **Problem:** P3, P4, P8.
- **Propozycja:**
  - Rozszerzyć `SimulationResult` o: `tier_rates` (mapa tier → {rate, ci_low, ci_high}),
    `estimated_attempts_to_jackpot` + CI, `expected_value`, `roi`, `baseline_delta`, `seed`.
  - **Ograniczyć `prize_details`**: przechowywać co najwyżej K przykładów per tier (np. 20)
    zamiast nieograniczonej listy → koniec wycieku pamięci P8.
  - Migracja: nowe pola opcjonalne; stare rekordy pozostają zgodne.
- **Pliki:** `simulation_result.ex`, `simulations.ex` (`PrizeTiersTracker.increment_tier` — cap listy),
  migracja Ecto (JSONB, bez zmiany kolumny — pola w embed).
- **Wpływ:** trwałe, bogate wyniki; brak degradacji pamięci przy długich przebiegach.
- **Nakład:** M · **Ryzyko:** niskie · **Akceptacja:** długi przebieg VIP2 ma stały narzut pamięci
  na `prize_details`; nowe pola serializują się i odczytują w analytics.

### Temat G — Poprawność i wydajność silnika

- **Problem:** P7, plus higiena hot-pathu.
- **Propozycja:**
  - **Dokładne liczenie prób**: w trybie estymacyjnym N jest ustalone i dzielone deterministycznie
    między Taski (np. `div(N, thread_count)` + reszta), zamiast wyścigu na współdzielonym liczniku
    z przekraczaniem `max_attempts`. Eliminuje P7 dla trybu MC.
  - **Koordynacja**: zamiast spawnowania nowej puli Tasków co rundę (`simulate_until_match`
    rekurencyjnie) rozważyć długożyjące workery czytające wspólny cel N (mniej alokacji GC).
  - **Broadcast progresu**: throttling czasowy (np. co 250 ms) zamiast co 100 prób — mniej wiadomości
    PubSub przy dużym `attempts/sec` (dziś `maybe_broadcast_progress` co 100 prób).
  - Po każdej zmianie: **re-run bench** i aktualizacja nagłówków (`bench/e2e_bench.exs`).
- **Pliki:** `simulations.ex` (koordynacja, broadcast), `bench/*.exs`.
- **Wpływ:** metryka bazowa staje się dokładna; mniejszy narzut przy skali.
- **Nakład:** M · **Ryzyko:** średnie (dotyka współbieżności — pełne testy + bench) ·
- **Akceptacja:** w trybie MC `attempts_count == N` dokładnie; bench nie regresuje względem
  zapisanych liczb.

### Temat H — Interpretowalność wyników (UX)

- **Problem:** P10.
- **Propozycja:** w widoku wyniku i rankingu prezentować: `p̂_tier ± CI`, EV/ROI, **deltę względem
  baseline'u losowego**, oraz **jawny baner „bias look-ahead"** dla trybów VIP1/VIP2 wyjaśniający,
  że przestrzeń została zawężona wiedzą o wyniku. Dodać krótkie objaśnienia „co ta liczba znaczy".
- **Pliki:** `simulation_components.ex`, `ranking_components.ex`, `dashboard_components.ex`,
  `simulations_live.ex`, `ranking_live.ex`. Do wykresów rozkładu — użyć skilla `dataviz`.
- **Wpływ:** wynik jest zrozumiały i uczciwy; mniejsze ryzyko błędnej interpretacji.
- **Nakład:** M · **Ryzyko:** niskie · **Akceptacja:** review UX; baner biasu widoczny dla VIP.

---

## 3. Mapa drogowa (fazy)

Kolejność dobrana wg *wartość / nakład* i zależności technicznych.

### Faza 1 — Fundamenty jakości *(szybkie, niskie ryzyko)*
- **Temat F (część):** cap `prize_details` (P8) — natychmiastowa poprawa pamięci. `S`
- **Temat D (część):** ziarno per-symulacja + seed w wyniku (P5), na razie tryb 1-wątkowy
  „reprodukowalny". `S–M`
- **Temat C (fundament):** moduł `Statistics` (Wilson CI, percentyle, z-test) z testami. `M`
- *Bramka:* `mix precommit` zielone; brak zmian w hot-pathcie → bench bez zmian.

### Faza 2 — Rdzeń wartości *(największy zwrot)*
- **Temat A:** tryb estymacyjny Monte Carlo + `Estimator` (P1, P2). `L`
- **Temat B:** tabela wypłat, EV/ROI, baseline losowy (P4). `M`
- **Temat F (reszta):** nowe pola w `SimulationResult` + migracja. `M`
- *Bramka:* re-run bench (dotyka silnika), aktualizacja nagłówków; testy własności estymatora.

### Faza 3 — Rygor i poprawność
- **Temat G:** dokładne liczenie prób w MC, throttling broadcastu, koordynacja (P7). `M`
- **Temat D (reszta):** niezależne strumienie RNG per-Task (P6). `M`
- **Temat C (reszta):** testy istotności A/B w rankingu (P3). `M`
- *Bramka:* pełne testy współbieżności + bench.

### Faza 4 — Framework eksperymentów
- **Temat E:** backtesting strategia × wiele losowań (P9), agregacja rozkładu. `L`
- *Uwaga:* dla Eurojackpot ograniczone historią w bazie — zacząć od Lotto (pełne archiwum).

### Faza 5 — Interpretowalność
- **Temat H:** UI metryk, delta-baseline, baner biasu look-ahead (P10). `M`
- Wykresy rozkładu/percentyli — skill `dataviz`.

---

## 4. Metryki sukcesu (jak poznamy, że się udało)

1. **Powtarzalność rankingu:** dwa niezależne uruchomienia estymacyjne tej samej strategii dają
   `p̂_jackpot` w nachodzących na siebie przedziałach ufności (dziś: rozrzut rzędów wielkości).
2. **Rozróżnialność strategii standardowych:** strategie w trybie standardowym mają różne, sensowne
   metryki wartości zamiast wspólnego sufitu `max_attempts` (P2 rozwiązane).
3. **Zgodność z teorią:** dla strategii czysto losowej `p̂_tier` zbiega do wartości analitycznej
   z `Analytics.comb/2` w granicach CI.
4. **Reprodukowalność:** przebieg 1-wątkowy z zapisanym seedem odtwarza się bit-w-bit.
5. **Uczciwość przekazu:** każdy wynik VIP ma jawny bias look-ahead; każda strategia ma deltę
   względem baseline'u losowego.
6. **Brak regresji wydajności:** liczby bench nie spadają poniżej zapisanych; pamięć `prize_details`
   ograniczona.
7. **Bramka:** `mix precommit` zielone na każdym kroku.

---

## 5. Ryzyka i mitigacje

| Ryzyko | Mitigacja |
|--------|-----------|
| Zmiana semantyki wyniku psuje stare rekordy/analytics | Nowe pola **opcjonalne**; `performance_score` (mediana) zostaje; migracje wstecznie zgodne. |
| Współbieżność + dokładne liczenie prób → subtelne bugi | Najpierw tryb 1-wątkowy referencyjny; property-based testy; bench + testy współbieżności przed scaleniem. |
| Dane wypłat są przybliżone / regionalne | Oznaczyć jako orientacyjne i uczynić konfigurowalnymi; EV podawać z założeniami. |
| Backtesting Eurojackpot ograniczony historią | Start od Lotto (pełne archiwum); dla Eurojackpot komunikować ograniczenie. |
| Bias look-ahead błędnie odczytany jako „przewaga" | Baner + delta-baseline obowiązkowe w UI (Temat H). |
| Regresja hot-pathu | Obowiązkowy re-run `bench/*.exs` i aktualizacja nagłówków po Fazach 2–3. |

---

## 6. Załącznik — konkretne punkty zaczepienia w kodzie

- Pętla symulacji i koordynacja: `lib/numbers_evolution/simulations.ex`
  (`simulate_until_match/1`, `process_simulation_attempts_parallel/1`, `run_attempt_batch/1`,
  `handle_unique_attempt/3`, `maybe_broadcast_progress/4`, `finalize_simulation/6`).
- Zliczanie tierów i pamięć: `Simulations.PrizeTiersTracker` (cap `increment_tier/5`).
- Generacja liczb (RNG, hot-path): `lib/numbers_evolution/strategies/generator.ex`.
- Schemat wyniku: `lib/numbers_evolution/simulations/simulation_result.ex`.
- Analityka i przestrzeń przeszukania: `lib/numbers_evolution/analytics.ex`
  (`comb/2`, `search_space_for_options/1`, `summarize_group/2`, `tiers_per_100k/2`).
- Konfiguracja gier (wypłaty, tiery, VIP): `lib/numbers_evolution/games.ex`.
- Score strategii: `Simulations.update_strategy_performance/1`,
  `Strategies.Strategy.performance_changeset/2`.
- Losowania do backtestingu: `lib/numbers_evolution/draws.ex` (`list_draws/1`, `count_draws/1`).
- Bench (bramka wydajności): `bench/e2e_bench.exs`, `bench/components_bench.exs`, `bench/support.exs`.
- UI wyników/rankingu: `lib/numbers_evolution_web/components/{simulation,ranking,dashboard}_components.ex`,
  `live/{simulations,ranking,dashboard}_live.ex`.

---

### Nowe moduły do utworzenia (podsumowanie)

- `NumbersEvolution.Statistics` — czyste funkcje: Wilson CI, z-test proporcji, bootstrap, percentyle.
- `NumbersEvolution.Simulations.Estimator` — liczniki tierów + N → rates, CI, oczekiwane próby, EV/ROI.
- `NumbersEvolution.Experiments` — orchestracja backtestingu strategia × zbiór losowań (Faza 4).

Moduły z Części II (samo-optymalizacja i algorytmy) — patrz sekcja 13.

---
---

# CZĘŚĆ II — Samo-optymalizacja, biblioteka algorytmów i ich mieszanie

> Rozszerzenie na życzenie: aby **algorytm i symulacje same się optymalizowały**, dokładały
> kolejne, niepowtarzalne algorytmy i szukały „złotego środka" (np. *symulacja trafiająca cel
> w ~100 próbach*), z możliwością **mieszania** algorytmów. Poniżej projektuję pętlę
> samo-optymalizacji, wspólny interfejs (warunek mieszania), 8 własnych algorytmów oraz mechanizmy
> ensemblingu. Zachowuję wszystkie zasady z Części II §0 (look-ahead intencjonalny, mediana=score,
> bench, precommit).

## 7. Idea „złotego środka" i pętla samo-optymalizacji

**Złoty środek** to punkt równowagi między dwoma skrajnościami tego symulatora:

```
przestrzeń za mała  ────────────[  ZŁOTY ŚRODEK  ]──────────── przestrzeń za duża
(k≈45: trafia w ~1 próbie,        (E[próby] ≈ setpoint,        (k=0: 1:139,8 mln,
 trywialne, max look-ahead)        czytelny sygnał, EV/robust)  nigdy nie trafia, brak sygnału)
```

Definicja formalna. Niech θ = wektor parametrów (rozmiary blacklisty `k,j`, wagi hot/cold/random,
ratio parzystości/low-high, pule preferowane). Setpoint `T` (domyślnie **100 prób**, konfigurowalny).
Cel jednokryterialny „złotego środka":

```
minimalizuj  | E[próby_do_celu | θ]  −  T |
```

gdzie `E[próby_do_celu | θ]` liczymy **analitycznie** z `Analytics.search_space_for_options/1`
(gdy dominuje pokrętło blacklisty) lub **estymujemy** krótką sondą Monte Carlo z Tematu A.

**Pętla samo-optymalizacji (meta-loop):**

```
θ₀ → [PROPOSE]  optymalizator proponuje θ
       ↓
     [PROBE]    krótki przebieg MC (N≈50–200k) → p̂_tier, E[próby], EV, CI   (Temat A/C)
       ↓
     [SCORE]    funkcja celu f(θ)  (sekcja 11)
       ↓
     [UPDATE]   optymalizator aktualizuje model/populację/knob
       ↓
     powtarzaj aż |E[próby] − T| < tol  albo  budżet wyczerpany  →  θ*
```

**Uczciwe zastrzeżenie (kluczowe).** Ponieważ look-ahead jest intencjonalny, „trafienie w 100 prób"
osiąga się *zawężając przestrzeń wiedzą o wyniku* — to **kalibracja/benchmark**, nie dowód mocy
predykcyjnej. Dlatego rozdzielamy dwa reżimy optymalizacji:

- **Reżim K (kalibracja):** cel = `E[próby] ≈ T`. Look-ahead dozwolony. Odpowiada wprost na prośbę
  „symulacja w 100 trafień". Wartość: powtarzalny, porównywalny benchmark trudności/efektywności.
- **Reżim W (wartość):** cel = maksymalizacja EV/ROI/robustności **bez** look-ahead, walidowana
  *out-of-sample* na losowaniach testowych (backtesting z Fazy 4). To tu samo-optymalizacja ma
  realną wartość analityczną, a nie tylko estetyczną.

Optymalizator wspiera oba reżimy tą samą pętlą — różni je tylko funkcja celu i to, czy sonda widzi
liczby docelowe.

## 8. Wspólny interfejs — warunek mieszania (behaviours)

Aby algorytmy dało się **wymieniać, składać i mieszać**, wprowadzamy dwa kontrakty. To jest
techniczny fundament całej Części II.

```elixir
# Silnik generujący kandydatów (jeden „gracz")
defmodule NumbersEvolution.Simulations.Algorithm do
  @callback init(opts :: keyword()) :: state :: term()
  @callback propose(state, ctx :: SimulationContext.t()) :: {combos :: [combo], state}
  @callback observe(state, feedback :: map()) :: state      # rates/tiery/energia z ostatniej paczki
  @callback params(state) :: map()                          # aktualny θ (do logowania/miksu)
end

# Optymalizator meta (dobiera θ dla dowolnego Algorithm)
defmodule NumbersEvolution.Simulations.Optimizer do
  @callback step(state, objective :: Objective.t(), probe :: (θ -> metrics)) :: {θ_next, state}
  @callback done?(state) :: boolean()
end
```

Istniejący `Strategies.Generator` staje się **pierwszą implementacją `Algorithm`** (adapter),
bez zmiany jego logiki — hot-path zostaje nietknięty, a nowe algorytmy dokładamy obok.
`observe/2` karmimy licznikami z `PrizeTiersTracker` (już zbierane).

## 9. Biblioteka algorytmów (moje propozycje)

Każdy: **cel · mechanizm · pokrętła · jak się samo-optymalizuje · zaczepienie w kodzie · koszt · zastrzeżenie.**

### Grupa A — Solvery „złotego środka" (reżim K, tanie i deterministyczne)

**ALG-1 · Analityczny inwerter przestrzeni (Golden-Mean Analytic)**
- *Cel:* dobrać `(k,j)` tak, by `C(50-k,5)·C(12-j,2) ≈ T` — natychmiastowy „100 trafień".
- *Mechanizm:* przeszukanie zamknięte po `k,j` (tabela `comb/2` jest mała) → wybór pary
  minimalizującej `|S(k,j) − T|`. Zero symulacji.
- *Pokrętła:* `T`, priorytet main vs euro blacklisty.
- *Samo-optymalizacja:* trywialna (inwersja funkcji). Punkt startowy dla ALG-2.
- *Kod:* `Analytics.comb/2`, `search_space_for_options/1`; nowy `Optimizer.Analytic`.
- *Koszt:* O(50·12). *Zastrzeżenie:* ignoruje constraints parzystości/dekad → obarczony biasem,
  stąd domknięcie feedbackiem (ALG-2).

**ALG-2 · Bisekcyjny kontroler ze sprzężeniem (Golden-Mean Feedback) — rdzeń „100 trafień"**
- *Cel:* zredukować *zmierzone* `E[próby]` do `T` mimo biasu modelu analitycznego.
- *Mechanizm:* traktuj `k` (rozmiar blacklisty) jako skalar; **bisekcja / kontroler proporcjonalny**
  na krótkich sondach MC: monotonicznie rosnące `k` skraca `E[próby]`, więc wyszukiwanie binarne
  zbiega w `O(log zakres)` sond do `|E[próby]−T| < tol`.
- *Pokrętła:* `T`, tolerancja, budżet sond `N`.
- *Samo-optymalizacja:* zamknięta pętla; dowodliwie zbieżna (monotoniczność).
- *Kod:* nowy `Optimizer.Bisection`; sonda = tryb MC z Tematu A.
- *Koszt:* ~10–15 sond × N. *Zastrzeżenie:* zakłada monotoniczność (spełniona dla pokrętła blacklisty).

### Grupa B — Optymalizatory meta (przeszukują pełne θ; reżim K lub W)

**ALG-3 · Ewolucja strategii (Genetic Strategy Search) — nawiązanie do nazwy projektu**
- *Cel:* ewoluować *całe strategie* (nie tylko blacklistę): ratio, wagi, hot/cold, `k,j`.
- *Mechanizm:* populacja genomów = `StrategyRules`; **selekcja turniejowa + krzyżowanie + mutacja**;
  fitness = `f(θ)` (sekcja 11). Elityzm zachowuje najlepsze. Naturalnie równoległe na `Task.Supervisor`.
- *Pokrętła:* rozmiar populacji, p. mutacji/krzyżowania, presja selekcyjna, liczba pokoleń.
- *Samo-optymalizacja:* to *jest* samo-optymalizacja — kod odkrywa strategie, nie człowiek.
- *Kod:* nowy `Optimizer.Genetic`; genom ↔ `StrategyRules` (koder/dekoder); fitness przez sondę MC.
- *Koszt:* pop × pokolenia × N (najdroższy, ale zawstydzająco równoległy).
- *Zastrzeżenie:* ryzyko przeuczenia na jednym losowaniu → w reżimie W fitness liczony na **wielu**
  losowaniach treningowych (Faza 4), walidacja na testowych.

**ALG-4 · Beznagradientowy optymalizator ciągły (Nelder–Mead / CMA-ES-lite)**
- *Cel:* dostroić **ciągłe** knoby (wagi hot/cold/random, proporcje) przy ustalonej strukturze.
- *Mechanizm:* simpleks Neldera–Meada (albo lekki CMA-ES) minimalizujący `f(θ)`; szybciej niż GA
  w gładkich, niskowymiarowych podprzestrzeniach.
- *Pokrętła:* rozmiar simpleksu, kryterium stopu.
- *Samo-optymalizacja:* lokalna, świetna jako *dokrętka* po globalnym GA/BO.
- *Kod:* nowy `Optimizer.NelderMead`; działa na wektorze wag z `StrategyRules.weights`.
- *Koszt:* dziesiątki sond. *Zastrzeżenie:* utyka w minimach lokalnych → łączyć z restartami/BO.

**ALG-5 · Bayesowska optymalizacja (TPE/GP surrogate) — nadrzędny orkiestrator**
- *Cel:* globalnie i **próbkooszczędnie** przeszukać całe θ (mieszane: ciągłe+dyskretne),
  optymalizując kosztowną funkcję celu (sonda MC = kosztowna ewaluacja).
- *Mechanizm:* surogat (Tree-Parzen Estimator, prostszy niż GP w Elixirze) + funkcja akwizycji
  (Expected Improvement) wybiera kolejne θ do zbadania. Minimalizuje liczbę sond.
- *Pokrętła:* budżet ewaluacji, eksploracja vs eksploatacja.
- *Samo-optymalizacja:* buduje model *mapy* θ→wynik i sam decyduje, gdzie próbkować.
- *Kod:* nowy `Optimizer.Bayesian`; spina ALG-3/4 jako lokalne dokrętki.
- *Koszt:* najniższa liczba sond na jakość. *Zastrzeżenie:* implementacja TPE nietrywialna → Faza 8.

### Grupa C — Alternatywne silniki próbkowania (inny sposób *docierania* do celu)

**ALG-6 · Symulowane wyżarzanie po kombinacjach (Guided Annealing Search)**
- *Cel:* **inny silnik niż i.i.d.** — ukierunkowany błądzenie zamiast ślepego losowania.
- *Mechanizm:* stan = kombinacja; energia `E = −(liczba trafionych liczb)`; ruch = podmiana 1–2 liczb
  na sąsiednie; akceptacja Boltzmanna `exp(−ΔE/temp)` z chłodzeniem. Konwerguje do wysokich tierów
  wielokrotnie szybciej niż random.
- *Pokrętła:* harmonogram chłodzenia, wielkość sąsiedztwa, restarty.
- *Samo-optymalizacja:* adaptacyjny harmonogram temperatury (auto-tuning wg akceptacji ~0,44).
- *Kod:* nowy `Algorithm.Annealing` (implementuje `propose/observe`); reużywa `count_matches`.
- *Koszt:* niska liczba kroków do wysokiego tieru. *Zastrzeżenie:* energia używa liczb docelowych
  → to metryka „jak szybko *ukierunkowane* szukanie zbiega" (spójna z look-ahead), nie uczciwej gry.

**ALG-7 · Pokrycie quasi-losowe (Low-Discrepancy / Latin Hypercube)**
- *Cel:* zastąpić i.i.d.+dedup **równomiernym pokryciem** przestrzeni → deterministyczne ograniczenie
  na próby do pokrycia zadanego ułamka przestrzeni; lepsza metryka „efektywności".
- *Mechanizm:* sekwencja o niskiej dyskrepancji (Halton/Sobol-lite) odwzorowana na indeks kombinacji;
  gwarantuje brak klastrów, których dedup nie naprawia.
- *Pokrętła:* baza sekwencji, permutacja startowa (z seeda — Temat D).
- *Samo-optymalizacja:* dobór bazy pod rozmiar przestrzeni.
- *Kod:* nowy `Algorithm.QuasiRandom`; alternatywa dla pętli w `run_attempt_batch`.
- *Koszt:* ~ i.i.d. *Zastrzeżenie:* mapowanie indeks→kombinacja z constraints wymaga rozwagi.

**ALG-8 · Bandyta portfelowy (Thompson Sampling / UCB1) — silnik mieszania**
- *Cel:* **mieszać** algorytmy: dynamicznie dzielić budżet prób między ALG-1…7 wg obserwowanej nagrody.
- *Mechanizm:* każdy algorytm = „ramię"; nagroda = hit-rate/EV z ostatniej paczki; Thompson Sampling
  (posterior Beta) lub UCB1 alokuje kolejne paczki do najbardziej obiecujących ramion. Samobalansujący.
- *Pokrętła:* priory, okno zapominania (dryf niestacjonarny).
- *Samo-optymalizacja:* z definicji — uczy się, który algorytm wygrywa *tu i teraz*.
- *Kod:* nowy `Optimizer.Bandit`; spina bibliotekę w jeden portfel.
- *Koszt:* pomijalny narzut nad samymi algorytmami.

## 10. Mieszanie (ensembling) — cztery wzorce

1. **Portfel-bandyta (ALG-8):** budżet prób dzielony adaptacyjnie między algorytmy. Najlepsze dla
   „nie wiem, który zadziała — niech kod zdecyduje".
2. **Generacja mieszaninowa (mixture):** każda próba losuje algorytm wg wag (uogólnienie istniejącego
   `weighted_random_pool/1` z `generator.ex` — z pokręteł na algorytmy, nie tylko pule hot/cold).
3. **Hybrydyzacja sekwencyjna:** globalne zgrubne przeszukanie (ALG-5/3) → region → lokalne dokrętki
   (ALG-4/2) → doprecyzowanie. Pipeline etapów.
4. **Stacking:** rozkład wyjściowy jednego algorytmu (np. gorące liczby z ALG-3) zasila pule
   preferowane drugiego (np. ALG-6). Kompozycja przez `params/1`→`init/1`.

Wszystkie cztery działają dzięki wspólnemu behaviour z sekcji 8 — to jest sedno „możemy je mieszać".

## 11. Funkcja celu (wielokryterialna, Pareto)

```
f(θ) = w₁·|E[próby] − T|            # bliskość „złotego środka" (reżim K)
     + w₂·(−EV(θ))                  # wartość oczekiwana / kupon (Temat B)
     + w₃·(−robustness(θ))          # stabilność między losowaniami (Faza 4, reżim W)
     + w₄·bias_penalty(θ)           # kara za degenerację do trywialnej przestrzeni
     + w₅·(−coverage_efficiency(θ)) # jak dobrze pokrywa przestrzeń (ALG-7)
```

- Wagi `w₁…₅` konfigurowalne; presety: **„Kalibracja 100"** (w₁ dominuje), **„Maks. wartość"**
  (w₂,w₃ dominują), **„Zbalansowany"**.
- Zamiast jednej liczby udostępniamy **front Pareto** (E[próby] vs EV vs robustność) i pozwalamy
  użytkownikowi wybrać punkt — to prawdziwie „złoty środek", nie arbitralny skalar.

## 12. Bezpieczeństwo metodologiczne (żeby to nie było oszukiwanie samego siebie)

- **Przeciek/przeuczenie:** reżim K jawnie oznaczony jako benchmark, nie predykcja. Reżim W
  **obowiązkowo** walidowany out-of-sample (trening na losowaniach A, ocena na B — Faza 4).
- **Guard rails optymalizatora:** minimalny rozmiar przestrzeni (`bias_penalty` rośnie do ∞ poniżej
  progu), by ALG-2/3 nie zdegenerowały do „blacklist wszystko oprócz celu".
- **Reprodukowalność sond:** każda sonda z seeda (Temat D) → wyniki optymalizacji audytowalne
  i deterministyczne przy re-runie.
- **Budżet obliczeń:** sondy używają taniego trybu MC (Temat A); cache `θ→metryki` (memoizacja)
  eliminuje powtórne ewaluacje; bandyta i BO minimalizują liczbę sond.
- **Bench + precommit:** nowe silniki (ALG-6/7) dotykają hot-pathu → obowiązkowy re-run `bench/*.exs`
  i aktualizacja nagłówków; wszystko przez `mix precommit` (max zagnieżdżenie 2, złożoność 9 —
  optymalizatory pisać jako małe, czyste funkcje + rekurencja ogonowa).

## 13. Integracja z kodem i nowe moduły

- `NumbersEvolution.Simulations.Algorithm` — behaviour (sekcja 8); adapter dla `Generator`.
- `NumbersEvolution.Simulations.Optimizer` — behaviour + implementacje:
  `Optimizer.{Analytic, Bisection, Genetic, NelderMead, Bayesian, Bandit}`.
- `NumbersEvolution.Simulations.Algorithm.{Annealing, QuasiRandom}` — alternatywne silniki.
- `NumbersEvolution.Simulations.Objective` — funkcja celu + presety wag + front Pareto.
- `NumbersEvolution.Simulations.Probe` — cienka warstwa: θ → krótki MC → metryki (reużywa Temat A/C).
- Zaczepienia: `search_space_for_options/1`, `comb/2` (`analytics.ex`); `weighted_random_pool/1`,
  `StrategyRules` (`generator.ex` — koder/dekoder genomu); `PrizeTiersTracker` (feedback);
  `Draws.list_draws/1` (robustność w reżimie W); config `options` (wybór algorytmu/optymalizatora).

## 14. Rozszerzenie mapy drogowej (Fazy 6–8)

### Faza 6 — „Złoty środek w 100 trafień" *(realizuje wprost prośbę)*
- Interfejs `Algorithm`/`Optimizer` (sekcja 8) + adapter `Generator`. `M`
- **ALG-1** (analityczny inwerter) i **ALG-2** (bisekcyjny kontroler) → setpoint `E[próby] ≈ T`. `M`
- `Probe` na bazie trybu MC (wymaga Fazy 2). `S`
- *Akceptacja:* dla `T=100` kontroler dobiera θ tak, że zmierzone `E[próby] ∈ [90,110]` powtarzalnie
  (ten sam seed → ten sam θ*); dla `T ∈ {50,100,1000}` skaluje poprawnie.

### Faza 7 — Samo-optymalizacja strategii *(reżim wartości)*
- **ALG-3** (ewolucja strategii) + `Objective` wielokryterialny + guard rails. `L`
- **ALG-4** (Nelder–Mead) jako lokalna dokrętka. `M`
- Walidacja out-of-sample na backtestingu (Faza 4). `M`
- *Akceptacja:* na losowaniach treningowych GA poprawia `f(θ)` monotonicznie; poprawa utrzymuje się
  na zbiorze testowym (brak przeuczenia > próg); trywialna degeneracja zablokowana przez `bias_penalty`.

### Faza 8 — Portfel i alternatywne silniki *(mieszanie)*
- **ALG-8** (bandyta) — portfel mieszający całą bibliotekę. `M`
- **ALG-6** (wyżarzanie), **ALG-7** (quasi-losowe) — nowe silniki. `L`
- **ALG-5** (optymalizacja bayesowska) — nadrzędny orkiestrator. `L`
- Front Pareto w UI (skill `dataviz`). `M`
- *Akceptacja:* bandyta na znanym benchmarku alokuje ≥70% budżetu do faktycznie najlepszego ramienia;
  ensemble nie jest gorszy od najlepszego pojedynczego algorytmu (własność „no-regret").

---

### Zaktualizowana lista nowych modułów (Część I + II)

- `Statistics`, `Simulations.Estimator`, `Experiments` *(Część I)*
- `Simulations.Algorithm` (+ `Algorithm.{Annealing, QuasiRandom}`)
- `Simulations.Optimizer` (+ `Optimizer.{Analytic, Bisection, Genetic, NelderMead, Bayesian, Bandit}`)
- `Simulations.Objective`, `Simulations.Probe`
