# Database Planning Summary - Numbers Evolution

**Data:** 14 listopada 2025  
**Wersja:** 1.0  
**Status:** Final Decisions

---

## Conversation Summary

### Decisions

Poniżej znajduje się lista wszystkich kluczowych decyzji podjętych przez użytkownika w temacie planowania bazy danych dla projektu Numbers Evolution:

#### 1. **Tabela `users` - Dodatkowe pola**
- ✅ Dodanie `inserted_at` i `updated_at` (timestamps) dla audytu
- ✅ Dodanie pola `preferences` (JSONB) dla przyszłych ustawień użytkownika (nullable w MVP1)

#### 2. **Soft Delete dla strategii**
- ✅ Strategie będą używać soft delete ze zmianą statusu
- ✅ Pole `status` (VARCHAR) z wartościami: `active`, `deleted`, `archived`
- ❌ Bez osobnego pola `deleted_at`

#### 3. **Walidacja JSON na poziomie bazy danych**
- ❌ Brak walidacji struktury JSON na poziomie PostgreSQL
- ✅ Walidacja tylko w Elixir/Ecto przez embedded schema
- ✅ Na poziomie DB: tylko sprawdzenie czy dane są poprawnym JSON (typ danych)

#### 4. **Tabela `draws` - Struktura uniwersalna**
- ✅ Unique index na `(game_type, draw_date)`
- ✅ Struktura `numbers` jako JSONB: `{"main_numbers": [...], "euro_numbers": [...]}`
- ✅ Pole `game_type` jako VARCHAR (nie ENUM)
- ✅ Walidacja typu gry w modelu Elixir, nie na DB
- ✅ Dodanie pola `source` (VARCHAR, nullable) z wartościami: `manual`, `import`, `admin`
- ❌ Brak dodatkowych pól: `draw_number`, `jackpot_amount`, `winners_count`, `verified`

#### 5. **Indeksy dla tabeli `simulations`**
- ✅ `idx_simulations_user_id` - filtrowanie po użytkowniku
- ✅ `idx_simulations_strategy_id` (partial: WHERE strategy_id IS NOT NULL)
- ✅ `idx_simulations_inserted_at_desc` - sortowanie chronologiczne
- ✅ `idx_simulations_user_strategy` - composite (user_id, strategy_id, status)

#### 6. **Relacja strategies-simulations przy usuwaniu**
- ❌ Bez `ON DELETE SET NULL` dla strategy_id
- ❌ Bez pola `strategy_snapshot` w simulations
- ✅ Tylko `strategy_id` (FK) bez duplikacji nazwy czy snapshot
- ✅ Soft delete strategii zapewni integralność historyczną

#### 7. **Row Level Security (RLS)**
- ✅ Włączenie RLS na tabelach: `strategies`, `simulations`, `events`
- ✅ Policy izolująca dane per użytkownik: `user_id = current_setting('app.current_user_id')::uuid`
- ❌ Bez RLS dla tabeli `draws` (dane publiczne)

#### 8. **Performance Score - Denormalizacja**
- ✅ Przechowywanie `performance_score` (float, nullable) w tabeli `strategies`
- ✅ Aktualizacja przez trigger PostgreSQL po INSERT/UPDATE/DELETE w `simulations`
- ✅ Funkcja `recalculate_performance_score()` używająca `percentile_cont(0.5)` dla mediany
- ✅ Przeliczanie tylko dla strategii której dotyczy zmiana (nie wszystkich)

#### 9. **Tabela `events` dla analytics**
- ✅ Struktura: `id`, `user_id`, `event_type`, `metadata` (JSONB), `inserted_at`
- ✅ Indeksy: `(user_id, inserted_at DESC)`, `(event_type)`, GIN index na `metadata`
- ✅ `event_type` jako VARCHAR (nie ENUM)
- ✅ CHECK constraint dla `event_type` z predefiniowaną listą wartości
- ✅ Dodanie logowania błędów komunikacji z AI w metadata

#### 10. **Partycjonowanie tabeli `simulations`**
- ❌ Brak partycjonowania na tym etapie
- ✅ Wystarczające indeksy dla MVP1
- 📝 Komentarz w migracji o potencjalnym partycjonowaniu w przyszłości (przy >1M rekordów)

#### 11. **Pola w tabeli `simulations`**
- ✅ Podstawowe pola: `attempts_count`, `duration_seconds`, `status`, `result` (JSONB)
- ✅ `started_at`, `completed_at` (timestamps)
- ❌ Bez pól: `timeout_ms`, `max_attempts`, `stop_reason`, `error_message`, `live_view_pid`
- ✅ Info o błędzie będzie w polu `result` (JSONB)
- ✅ Timeout limit i max_attempts na sztywno w aplikacji

#### 12. **Embedded Schema dla `rules`**
- ✅ Dynamiczny JSON w tej samej tabeli (nie osobna tabela)
- ✅ Możliwość dodania pola tekstowego definiującego strategię
- ✅ `rules` jako zestaw filtrów i zasad w JSONB
- ✅ Elastyczna struktura pozwalająca np. "odciąć połowę liczb przed losowaniem"

#### 13. **Tabela `events` - Relacje z encjami**
- ✅ Użycie JSONB metadata (nie polymorphic associations)
- ✅ Struktura metadata: `{"entity_type": "...", "entity_id": "...", "ai_provider": "...", ...}`
- ❌ Bez osobnych kolumn `entity_type` i `entity_id`

#### 14. **Constraints na tabeli `simulations`**
- ✅ `CHECK (status IN ('pending', 'running', 'success', 'timeout', 'error', 'cancelled'))`
- ✅ `CHECK (attempts_count >= 0)`
- ✅ `CHECK (duration_seconds >= 0)`
- ✅ `CHECK (completed_at IS NULL OR completed_at >= started_at)`
- ✅ `CHECK (status != 'success' OR result IS NOT NULL)`
- ✅ `CHECK (status != 'error' OR error_message IS NOT NULL)` - ale error_message w `result` JSONB

#### 15. **Strategy Mixes - Tracking**
- ❌ Bez osobnej tabeli `strategy_mixes`
- ❌ Bez pola `source_strategy_ids` (array of UUID)
- ✅ Wystarczy odpowiednie połączenie w nazwie oraz `rules`

#### 16. **Unique Constraints**
- ✅ `users.email` - UNIQUE
- ✅ `draws(game_type, draw_date)` - UNIQUE
- ❌ Bez UNIQUE na `strategies.name` - użytkownik może mieć duplikaty nazw
- ❌ Bez UNIQUE na `simulations` - można uruchamiać tę samą strategię wielokrotnie
- ❌ Bez UNIQUE na `events`

#### 17. **Funkcja recalculate_performance_score()**
- ✅ Trigger AFTER INSERT OR UPDATE OR DELETE na `simulations`
- ✅ Przeliczanie tylko dla strategii której dotyczy zmiana (`NEW.strategy_id` lub `OLD.strategy_id`)
- ✅ Mediana tylko dla successful simulations (`status = 'success'`)
- ✅ Update `strategies.performance_score` i `updated_at`

---

### Matched Recommendations

Poniżej znajdują się rekomendacje, które zostały zaakceptowane lub zmodyfikowane na podstawie odpowiedzi użytkownika:

#### 1. **Akceptowane w pełni:**

1. **Timestamps dla audytu** - Dodanie `inserted_at` i `updated_at` do wszystkich głównych tabel
2. **Indeksy dla simulations** - Wszystkie zaproponowane indeksy zostały zaakceptowane
3. **Row Level Security** - Pełna implementacja dla izolacji danych użytkowników
4. **Performance Score jako denormalizacja** - Trigger PostgreSQL z funkcją przeliczającą medianę
5. **Struktura tabeli events** - JSONB metadata dla elastyczności
6. **Constraints na simulations** - Wszystkie walidacje integralności danych
7. **Unique constraints** - Zgodność z zaproponowanymi ograniczeniami unikalności
8. **Funkcja recalculate_performance_score** - Implementacja zgodnie z rekomendacją

#### 2. **Zmodyfikowane:**

9. **Soft delete strategii** - Zamiast `deleted_at`, użycie pola `status` (VARCHAR) z wartościami `active`/`deleted`/`archived`
10. **Game type w draws** - VARCHAR zamiast ENUM dla lepszej elastyczności
11. **Event type** - VARCHAR zamiast ENUM, walidacja w aplikacji
12. **Pola w draws** - Tylko `source` dodane, bez `draw_number`, `jackpot_amount` itd.
13. **Strategy snapshot** - Usunięty, tylko `strategy_id` w simulations
14. **Dodatkowe pola simulations** - Uproszczone, błędy w JSONB `result`

#### 3. **Odrzucone:**

15. **Walidacja JSON na poziomie DB** - Walidacja tylko w Ecto/embedded schema
16. **Partycjonowanie w MVP1** - Odłożone, tylko indeksy
17. **Strategy_snapshot** - Nie potrzebne dzięki soft delete
18. **Source_strategy_ids** - Nie potrzebne dla mixów
19. **Entity_type/entity_id kolumny** - Tylko metadata JSONB

---

### Database Planning Summary

#### Główne wymagania schematu bazy danych

Numbers Evolution to aplikacja do testowania strategii typowania liczb w Eurojackpot. Baza danych musi wspierać:

1. **Autoryzację użytkowników** - rejestracja, login, zarządzanie sesją
2. **Zarządzanie strategiami** - CRUD, generowanie przez AI, soft delete
3. **Symulacje** - uruchamianie, tracking, zapis wyników
4. **Dane historyczne** - 100-200 losowań Eurojackpot
5. **Ranking** - kalkulacja performance score (mediana prób)
6. **Analytics** - logowanie eventów użytkowników

#### Kluczowe encje i ich relacje

##### 1. **Users (Użytkownicy)**
```
users
├── id (UUID, PK)
├── email (VARCHAR, UNIQUE)
├── hashed_password (VARCHAR)
├── confirmed_at (TIMESTAMP)
├── preferences (JSONB, nullable)
├── inserted_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

**Relacje:**
- `users` 1:N `strategies` (user_id FK)
- `users` 1:N `simulations` (user_id FK)
- `users` 1:N `events` (user_id FK)

**Uwagi:**
- Generowane przez `phx.gen.auth`
- `preferences` JSONB dla przyszłych ustawień (np. domyślne limity)

##### 2. **Strategies (Strategie)**
```
strategies
├── id (UUID, PK)
├── user_id (UUID, FK → users.id ON DELETE CASCADE)
├── name (VARCHAR)
├── type (VARCHAR) - 'manual', 'ai_generated'
├── status (VARCHAR) - 'active', 'deleted', 'archived'
├── rules (JSONB) - dynamiczna struktura filtrów i zasad
├── ai_prompt (TEXT, nullable)
├── performance_score (FLOAT, nullable) - denormalizowany
├── inserted_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

**Relacje:**
- `strategies` N:1 `users`
- `strategies` 1:N `simulations` (strategy_id FK)

**Indeksy:**
- `idx_strategies_user_id` (user_id)
- `idx_strategies_type` (type)
- `idx_strategies_status` (status) - partial WHERE status = 'active'
- `idx_strategies_performance_score` (performance_score)
- `idx_strategies_user_performance` (user_id, performance_score)
- `idx_strategies_rules_gin` (rules) - GIN index dla JSONB queries

**Uwagi:**
- Soft delete przez zmianę `status` na 'deleted'
- `rules` jako elastyczny JSONB pozwala na różne typy strategii
- `performance_score` aktualizowany triggerem po każdej symulacji

##### 3. **Draws (Losowania)**
```
draws
├── id (UUID, PK)
├── draw_date (DATE)
├── game_type (VARCHAR) - 'eurojackpot', 'lotto', 'multi_multi'
├── numbers (JSONB) - {"main_numbers": [1,7,23,34,50], "euro_numbers": [3,9]}
├── source (VARCHAR, nullable) - 'manual', 'import', 'admin'
├── inserted_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

**Relacje:**
- `draws` 1:N `simulations` (target_draw_id FK)

**Indeksy:**
- UNIQUE (game_type, draw_date)
- `idx_draws_game_type` (game_type)
- `idx_draws_date` (draw_date DESC)
- `idx_draws_numbers_gin` (numbers) - GIN index dla JSONB

**Uwagi:**
- Uniwersalna struktura przygotowana na inne gry
- `numbers` JSONB elastyczne - różne gry mają różne formaty
- Dane publiczne - bez RLS

##### 4. **Simulations (Symulacje)**
```
simulations
├── id (UUID, PK)
├── user_id (UUID, FK → users.id ON DELETE CASCADE)
├── strategy_id (UUID, FK → strategies.id ON DELETE SET NULL, nullable)
├── target_draw_id (UUID, FK → draws.id ON DELETE CASCADE)
├── attempts_count (BIGINT)
├── duration_seconds (FLOAT)
├── status (VARCHAR) - 'pending', 'running', 'success', 'timeout', 'error', 'cancelled'
├── result (JSONB) - szczegóły wyniku, w tym error info
├── started_at (TIMESTAMP)
├── completed_at (TIMESTAMP, nullable)
├── inserted_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

**Relacje:**
- `simulations` N:1 `users`
- `simulations` N:1 `strategies` (nullable dla soft-deleted)
- `simulations` N:1 `draws`

**Indeksy:**
- `idx_simulations_user_id` (user_id)
- `idx_simulations_strategy_id` (strategy_id) WHERE strategy_id IS NOT NULL
- `idx_simulations_inserted_at_desc` (inserted_at DESC)
- `idx_simulations_user_strategy` (user_id, strategy_id, status)
- `idx_simulations_status` (status)

**Constraints:**
```sql
CHECK (status IN ('pending', 'running', 'success', 'timeout', 'error', 'cancelled'))
CHECK (attempts_count >= 0)
CHECK (duration_seconds >= 0)
CHECK (completed_at IS NULL OR completed_at >= started_at)
CHECK (status != 'success' OR result IS NOT NULL)
```

**Uwagi:**
- `strategy_id` nullable dla zachowania symulacji po soft delete strategii
- Timeout i max_attempts hardcoded w aplikacji (nie w DB)
- `result` JSONB zawiera zarówno sukces jak i błędy

##### 5. **Events (Analytics)**
```
events
├── id (UUID, PK)
├── user_id (UUID, FK → users.id ON DELETE CASCADE)
├── event_type (VARCHAR)
├── metadata (JSONB)
└── inserted_at (TIMESTAMP)
```

**Relacje:**
- `events` N:1 `users`

**Indeksy:**
- `idx_events_user_date` (user_id, inserted_at DESC)
- `idx_events_type` (event_type)
- `idx_events_metadata_gin` (metadata) - GIN index

**Constraints:**
```sql
CHECK (event_type IN (
  'strategy_created', 
  'simulation_started', 
  'simulation_completed',
  'coupons_generated',
  'strategy_mix_created',
  'ai_error',
  'ai_success'
))
```

**Uwagi:**
- Logowanie akcji użytkowników + błędy AI
- Elastyczna struktura metadata dla różnych typów eventów
- Przykład metadata: `{"entity_type": "strategy", "entity_id": "uuid", "ai_provider": "openai", "error_type": "rate_limit"}`

#### Ważne kwestie dotyczące bezpieczeństwa i skalowalności

##### Bezpieczeństwo

**1. Row Level Security (RLS)**

Implementacja izolacji danych per użytkownik:

```sql
-- Strategie
ALTER TABLE strategies ENABLE ROW LEVEL SECURITY;
CREATE POLICY strategies_isolation ON strategies
  FOR ALL TO authenticated_user
  USING (user_id = current_setting('app.current_user_id')::uuid);

-- Symulacje
ALTER TABLE simulations ENABLE ROW LEVEL SECURITY;
CREATE POLICY simulations_isolation ON simulations
  FOR ALL TO authenticated_user
  USING (user_id = current_setting('app.current_user_id')::uuid);

-- Eventy
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY events_isolation ON events
  FOR ALL TO authenticated_user
  USING (user_id = current_setting('app.current_user_id')::uuid);
```

**Ustawienie w Ecto Repo:**
```elixir
# Przy każdej transakcji
Repo.query("SET LOCAL app.current_user_id = $1", [user.id])
```

**2. Walidacja danych**

- **Ecto changesets** - główna walidacja na poziomie aplikacji
- **Embedded schemas** - dla JSONB fields (rules, result, metadata)
- **CHECK constraints** - podstawowa integralność na DB
- **Foreign keys** z odpowiednimi ON DELETE actions

**3. Soft Delete**

Strategie używają soft delete (`status = 'deleted'`):
- Zachowuje integralność historyczną symulacji
- Umożliwia "undelete" w przyszłości
- Wymaga filtrowania w queries: `WHERE status = 'active'`

**4. Audit Trail**

- `inserted_at`, `updated_at` na wszystkich tabelach
- Tabela `events` dla logowania akcji
- Trigger aktualizujący `updated_at` przy każdej zmianie

##### Skalowalność

**1. Indeksowanie**

Strategia indeksowania zoptymalizowana pod:
- Queries filtrujące po user_id (najczęstsze)
- Sortowanie po performance_score (rankingi)
- Queries po JSONB fields (GIN indexes)
- Partial indexes dla często używanych filtrów

**2. Denormalizacja**

`performance_score` w tabeli `strategies`:
- Unika kosztownych agregacji przy każdym query
- Aktualizowany triggerem automatycznie
- Trade-off: consistency za performance

**3. Przyszła skalowalność (post-MVP)**

Przygotowanie na wzrost:
- **Partycjonowanie `simulations`** przy >1M rekordów
  - Po `inserted_at` (monthly/quarterly)
  - Lub po `user_id` (hash partitioning)
- **Connection pooling** - Ecto.Repo pool_size
- **Read replicas** dla analytics queries
- **Caching** - Redis dla często czytanych danych (rankings, draw data)

**4. Monitoring**

Metryki do monitorowania:
- Rozmiar tabel (szczególnie `simulations`)
- Query performance (slow query log)
- Index usage (pg_stat_user_indexes)
- Connection pool saturation

#### Trigger: recalculate_performance_score

**Implementacja funkcji:**

```sql
CREATE OR REPLACE FUNCTION recalculate_performance_score()
RETURNS TRIGGER AS $$
DECLARE
  affected_strategy_id UUID;
  new_score FLOAT;
BEGIN
  -- Określ którą strategię zaktualizować
  affected_strategy_id := COALESCE(NEW.strategy_id, OLD.strategy_id);
  
  IF affected_strategy_id IS NOT NULL THEN
    -- Oblicz medianę tylko dla successful simulations
    SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY attempts_count)
    INTO new_score
    FROM simulations
    WHERE strategy_id = affected_strategy_id 
      AND status = 'success';
    
    -- Aktualizuj strategię
    UPDATE strategies
    SET performance_score = new_score,
        updated_at = NOW()
    WHERE id = affected_strategy_id;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER update_strategy_performance
AFTER INSERT OR UPDATE OR DELETE ON simulations
FOR EACH ROW EXECUTE FUNCTION recalculate_performance_score();
```

**Optymalizacje:**
- Przelicza tylko dla jednej strategii (nie wszystkich)
- Używa mediany zamiast średniej (mniej wrażliwe na outliers)
- Tylko successful simulations brane pod uwagę

---

### Unresolved Issues

Poniżej znajdują się kwestie, które mogą wymagać dalszych wyjaśnień lub decyzji w przyszłości:

#### 1. **Migracja danych przy zmianie strategii**

**Pytanie:** Co się dzieje z `performance_score` gdy użytkownik edytuje `rules` strategii?

**Opcje:**
- A) Reset `performance_score` do NULL (wszystkie dotychczasowe symulacje nieważne)
- B) Pozostaw `performance_score` (stare symulacje bazują na starych rules)
- C) Zachowaj historię (nowa wersja strategii = nowy rekord)

**Rekomendacja:** Opcja B w MVP1 (najprostsza), ale dodaj `updated_at` check w UI z informacją "Strategia edytowana po symulacjach - wyniki mogą być nieaktualne"

#### 2. **Limit wielkości JSONB fields**

**Pytanie:** Czy są limity wielkości dla `rules`, `result`, `metadata`?

**Potencjalne problemy:**
- Bardzo złożone strategie → duże `rules`
- AI generujące nadmiarowe dane → duże `metadata`
- PostgreSQL JSONB limit: 1GB per value (praktycznie nieograniczony)

**Rekomendacja:** Dodać soft limit w aplikacji:
- `rules`: max 100KB
- `result`: max 50KB  
- `metadata`: max 100KB
- Walidacja w Ecto changeset

#### 3. **Archiwizacja starych symulacji**

**Pytanie:** Czy istnieje polityka retencji danych dla `simulations`?

**Scenariusz:** Tabela `simulations` może rosnąć szybko przy active users

**Opcje:**
- A) Brak archiwizacji - trzymaj wszystko
- B) Archiwizacja po 6-12 miesiącach (osobna tabela `archived_simulations`)
- C) Agregacja - trzymaj tylko statystyki (mediana, liczba), usuń szczegóły

**Rekomendacja:** Opcja A w MVP1, przemyśl archiwizację przy >1M rekordów

#### 4. **Replikacja danych draws między środowiskami**

**Pytanie:** Jak synchronizować dane `draws` między dev/staging/production?

**Scenariusze:**
- Nowe losowanie raz w tygodniu
- Musi być w dev dla testów
- Musi być w production dla użytkowników

**Opcje:**
- A) Manual seeding każdego środowiska
- B) Shared read-only database dla draws (overkill)
- C) Automated seed script (np. GitHub Action)

**Rekomendacja:** Opcja A w MVP1 (manual), seed files commitowane do repo

#### 5. **Handling strategii po usunięciu użytkownika**

**Pytanie:** Co dzieje się ze strategiami i symulacjami gdy user jest usuwany?

**Obecna decyzja:** `ON DELETE CASCADE` dla wszystkich FK

**Potencjalny problem:** Utrata wszystkich danych użytkownika bezpowrotnie

**Alternatywy:**
- Soft delete użytkowników (GDPR compliance - możliwość anonimizacji)
- Orphan strategies (zmiana owner_id na NULL, strategie stają się "anonymous")

**Rekomendacja:** Obecna opcja OK dla MVP1, przemyśl soft delete users przy GDPR requirements

#### 6. **Transakcje przy tworzeniu mixów strategii**

**Pytanie:** Czy tworzenie strategy mix powinno być atomowe (transakcja)?

**Scenariusz:** Mix tworzy nową strategię z połączenia 2-3 istniejących

**Potencjalne problemy:**
- AI fail po połowie procesu
- Source strategies usunięte podczas tworzenia mix
- Rollback przy błędzie

**Rekomendacja:** Tak, użyj `Repo.transaction` w kontekście Strategies:
```elixir
Repo.transaction(fn ->
  with {:ok, source_strategies} <- validate_sources(ids),
       {:ok, mix_rules} <- AI.mix_strategies(source_strategies),
       {:ok, strategy} <- create_strategy(user, mix_rules) do
    strategy
  else
    error -> Repo.rollback(error)
  end
end)
```

#### 7. **Kolejkowanie symulacji vs natychmiastowe uruchomienie**

**Pytanie:** Czy wszystkie symulacje uruchamiać natychmiast czy kolejkować?

**Obecna decyzja:** `Task.async` (natychmiastowe)

**Potencjalne problemy przy skali:**
- 100 użytkowników × 10 symulacji równolegle = 1000 Tasks
- Możliwe przeciążenie systemu

**Opcje:**
- A) Obecne (Task.async) - OK dla MVP1
- B) Queue (Oban) - lepsze dla większej skali
- C) Hybrid - kolejka + priority (premium users first)

**Rekomendacja:** Opcja A w MVP1, przejdź na Oban gdy >50 concurrent users

#### 8. **Backup strategy**

**Pytanie:** Jak często backup PostgreSQL? Retention?

**Dla Fly.io:**
- Managed Postgres ma automatic daily backups
- Retention: 7 days na hobby tier

**Rekomendacja:** 
- Użyj Fly.io managed backups w MVP1
- Rozważ własne backups (pgdump) tygodniowo dla long-term retention

#### 9. **Migracje w produkcji**

**Pytanie:** Strategia safe migrations (zero-downtime)?

**Potencjalne problemy:**
- Dodanie NOT NULL column na dużej tabeli
- Zmiana typu kolumny
- Usunięcie kolumny używanej przez running code

**Rekomendacja:** Best practices:
- Zawsze dodawaj kolumny jako nullable najpierw
- Backfill w osobnym zadaniu
- Dodaj NOT NULL w kolejnej migracji
- Używaj `strong_migrations` gem (Elixir equivalent: custom checks)

---

## Podsumowanie Schema

### Tabele (5):
1. **users** - Autoryzacja i dane użytkowników
2. **strategies** - Strategie typowania (manual + AI)
3. **draws** - Historyczne losowania (seeded data)
4. **simulations** - Wyniki symulacji
5. **events** - Logi analytics i błędów

### Relacje:
```
users 1───N strategies
users 1───N simulations  
users 1───N events
strategies 1───N simulations
draws 1───N simulations
```

### Indexes (17):
- 6 na `strategies`
- 5 na `simulations`
- 3 na `draws`
- 3 na `events`

### Triggers (1):
- `update_strategy_performance` - auto-update performance_score

### Constraints:
- CHECK constraints dla statusów i validacji
- Foreign keys z odpowiednimi ON DELETE actions
- UNIQUE constraints dla unikalności danych

### Security:
- Row Level Security (RLS) na 3 tabelach
- Walidacja w Ecto/embedded schemas
- Audit trail (timestamps)

---

## Next Steps

### Implementacja (Tydzień 1-2):

1. ✅ **Setup projektu:** `mix phx.new numbers_evolution`
2. ✅ **Auth:** `mix phx.gen.auth Accounts User users`
3. ✅ **Migracje:**
   - Dodaj `preferences` do users
   - Stwórz `strategies` table
   - Stwórz `draws` table
   - Stwórz `simulations` table
   - Stwórz `events` table
4. ✅ **Indeksy:** Dodaj wszystkie zaplanowane indeksy
5. ✅ **Funkcja i trigger:** `recalculate_performance_score()`
6. ✅ **RLS policies:** Implementuj Row Level Security
7. ✅ **Seed data:** 100-200 losowań + 15 template strategii
8. ✅ **Embedded schemas:** Dla `rules`, `result`, `metadata`

### Testowanie:

- Unit testy dla Ecto schemas
- Integration testy dla RLS policies
- Performance testy dla trigger (przy dużej liczbie symulacji)
- Migracje backwards compatibility

### Monitoring:

- Query performance (pg_stat_statements)
- Table sizes (`pg_total_relation_size`)
- Index usage (`pg_stat_user_indexes`)
- RLS overhead
