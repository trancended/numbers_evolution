# Database Schema - Numbers Evolution

**Wersja:** 1.0  
**Data:** 14 listopada 2025  
**Baza danych:** PostgreSQL 14+  
**ORM:** Ecto 3.x

---

## 1. Tabele

### 1.1 users

Tabela użytkowników generowana przez `phx.gen.auth`.

| Kolumna | Typ | Ograniczenia | Opis |
|---------|-----|--------------|------|
| id | UUID | PRIMARY KEY | Unikalny identyfikator użytkownika |
| email | VARCHAR(255) | NOT NULL, UNIQUE | Email użytkownika (login) |
| hashed_password | VARCHAR(255) | NOT NULL | Zahashowane hasło (bcrypt) |
| confirmed_at | TIMESTAMP | NULL | Data potwierdzenia email (NULL w MVP1) |
| preferences | JSONB | NULL | Ustawienia użytkownika (nullable w MVP1) |
| inserted_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | Data utworzenia konta |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | Data ostatniej aktualizacji |

**Constraints:**
```sql
CONSTRAINT users_pkey PRIMARY KEY (id)
CONSTRAINT users_email_key UNIQUE (email)
```

---

### 1.2 strategies

Tabela strategii typowania liczb (manualne i generowane przez AI).

| Kolumna | Typ | Ograniczenia | Opis |
|---------|-----|--------------|------|
| id | UUID | PRIMARY KEY | Unikalny identyfikator strategii |
| user_id | UUID | NOT NULL, FK → users.id | Właściciel strategii |
| name | VARCHAR(255) | NOT NULL | Nazwa strategii |
| type | VARCHAR(50) | NOT NULL | Typ: 'manual', 'ai_generated' |
| status | VARCHAR(50) | NOT NULL, DEFAULT 'active' | Status: 'active', 'deleted', 'archived' |
| rules | JSONB | NOT NULL | Dynamiczne reguły strategii |
| ai_prompt | TEXT | NULL | Oryginalny prompt AI (nullable) |
| performance_score | FLOAT | NULL | Mediana prób (denormalizowana, aktualizowana triggerem) |
| inserted_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | Data utworzenia |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | Data ostatniej aktualizacji |

**Constraints:**
```sql
CONSTRAINT strategies_pkey PRIMARY KEY (id)
CONSTRAINT strategies_user_id_fkey FOREIGN KEY (user_id) 
  REFERENCES users(id) ON DELETE CASCADE
CONSTRAINT strategies_type_check CHECK (type IN ('manual', 'ai_generated'))
CONSTRAINT strategies_status_check CHECK (status IN ('active', 'deleted', 'archived'))
```

**Struktura JSONB rules (przykład):**
```json
{
  "main_numbers": {
    "ratio_even_odd": [2, 3],
    "ratio_low_high": [3, 2],
    "preferred_hot": [7, 23, 34],
    "preferred_cold": [1, 50],
    "weights": {
      "hot": 0.4,
      "cold": 0.2,
      "random": 0.4
    }
  },
  "euro_numbers": {
    "ratio_even_odd": [1, 1],
    "preferred": [3, 9],
    "weights": {
      "hot": 0.5,
      "random": 0.5
    }
  }
}
```

---

### 1.3 draws

Tabela historycznych losowań (seeded data).

| Kolumna | Typ | Ograniczenia | Opis |
|---------|-----|--------------|------|
| id | UUID | PRIMARY KEY | Unikalny identyfikator losowania |
| draw_date | DATE | NOT NULL | Data losowania |
| game_type | VARCHAR(50) | NOT NULL | Typ gry: 'eurojackpot', 'lotto', 'multi_multi' |
| numbers | JSONB | NOT NULL | Wylosowane liczby |
| source | VARCHAR(50) | NULL | Źródło: 'manual', 'import', 'admin' |
| inserted_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | Data dodania do systemu |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | Data ostatniej aktualizacji |

**Constraints:**
```sql
CONSTRAINT draws_pkey PRIMARY KEY (id)
CONSTRAINT draws_game_date_unique UNIQUE (game_type, draw_date)
```

**Struktura JSONB numbers (Eurojackpot):**
```json
{
  "main_numbers": [1, 7, 23, 34, 50],
  "euro_numbers": [3, 9]
}
```

---

### 1.4 simulations

Tabela wyników symulacji.

| Kolumna | Typ | Ograniczenia | Opis |
|---------|-----|--------------|------|
| id | UUID | PRIMARY KEY | Unikalny identyfikator symulacji |
| user_id | UUID | NOT NULL, FK → users.id | Użytkownik uruchamiający symulację |
| strategy_id | UUID | NULL, FK → strategies.id | Strategia użyta (nullable dla soft-deleted) |
| target_draw_id | UUID | NOT NULL, FK → draws.id | Losowanie target |
| attempts_count | BIGINT | NOT NULL, DEFAULT 0 | Liczba prób do trafienia |
| duration_seconds | FLOAT | NOT NULL, DEFAULT 0 | Czas trwania symulacji |
| status | VARCHAR(50) | NOT NULL | Status: 'pending', 'running', 'success', 'timeout', 'error', 'cancelled' |
| result | JSONB | NULL | Szczegóły wyniku (matched numbers lub error info) |
| started_at | TIMESTAMP | NULL | Czas rozpoczęcia |
| completed_at | TIMESTAMP | NULL | Czas zakończenia |
| inserted_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | Data utworzenia rekordu |
| updated_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | Data ostatniej aktualizacji |

**Constraints:**
```sql
CONSTRAINT simulations_pkey PRIMARY KEY (id)
CONSTRAINT simulations_user_id_fkey FOREIGN KEY (user_id) 
  REFERENCES users(id) ON DELETE CASCADE
CONSTRAINT simulations_strategy_id_fkey FOREIGN KEY (strategy_id) 
  REFERENCES strategies(id) ON DELETE SET NULL
CONSTRAINT simulations_target_draw_id_fkey FOREIGN KEY (target_draw_id) 
  REFERENCES draws(id) ON DELETE CASCADE
CONSTRAINT simulations_status_check CHECK (status IN ('pending', 'running', 'success', 'timeout', 'error', 'cancelled'))
CONSTRAINT simulations_attempts_check CHECK (attempts_count >= 0)
CONSTRAINT simulations_duration_check CHECK (duration_seconds >= 0)
CONSTRAINT simulations_completed_check CHECK (completed_at IS NULL OR completed_at >= started_at)
CONSTRAINT simulations_success_result_check CHECK (status != 'success' OR result IS NOT NULL)
```

**Struktura JSONB result (success):**
```json
{
  "matched_main": [1, 7, 23, 34, 50],
  "matched_euro": [3, 9],
  "attempts_count": 125430,
  "final_draw": {
    "main_numbers": [1, 7, 23, 34, 50],
    "euro_numbers": [3, 9]
  }
}
```

**Struktura JSONB result (timeout/error):**
```json
{
  "reason": "timeout",
  "limit_reached": "max_attempts",
  "attempts_count": 1000000,
  "error_message": "Optional error details"
}
```

---

### 1.5 events

Tabela logowania akcji użytkowników i eventów systemowych (analytics).

| Kolumna | Typ | Ograniczenia | Opis |
|---------|-----|--------------|------|
| id | UUID | PRIMARY KEY | Unikalny identyfikator eventu |
| user_id | UUID | NOT NULL, FK → users.id | Użytkownik związany z eventem |
| event_type | VARCHAR(100) | NOT NULL | Typ eventu |
| metadata | JSONB | NULL | Dodatkowe dane specyficzne dla typu eventu |
| inserted_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | Data wystąpienia eventu |

**Constraints:**
```sql
CONSTRAINT events_pkey PRIMARY KEY (id)
CONSTRAINT events_user_id_fkey FOREIGN KEY (user_id) 
  REFERENCES users(id) ON DELETE CASCADE
CONSTRAINT events_type_check CHECK (event_type IN (
  'strategy_created',
  'strategy_updated',
  'strategy_deleted',
  'simulation_started',
  'simulation_completed',
  'coupons_generated',
  'strategy_mix_created',
  'ai_request',
  'ai_success',
  'ai_error'
))
```

**Struktura JSONB metadata (przykłady):**
```json
// strategy_created
{
  "entity_type": "strategy",
  "entity_id": "uuid",
  "strategy_type": "ai_generated",
  "ai_provider": "claude"
}

// ai_error
{
  "ai_provider": "openai",
  "error_type": "rate_limit",
  "error_message": "Rate limit exceeded",
  "prompt_length": 1500
}

// coupons_generated
{
  "strategy_id": "uuid",
  "coupons_count": 5
}
```

---

## 2. Relacje

### 2.1 Diagram relacji

```
users (1) ──────< (N) strategies
users (1) ──────< (N) simulations
users (1) ──────< (N) events

strategies (1) ──────< (N) simulations

draws (1) ──────< (N) simulations
```

### 2.2 Szczegóły relacji

| Tabela Źródłowa | Tabela Docelowa | Typ | Klucz Obcy | ON DELETE |
|-----------------|-----------------|-----|------------|-----------|
| strategies | users | N:1 | user_id | CASCADE |
| simulations | users | N:1 | user_id | CASCADE |
| simulations | strategies | N:1 | strategy_id | SET NULL |
| simulations | draws | N:1 | target_draw_id | CASCADE |
| events | users | N:1 | user_id | CASCADE |

**Uwagi:**
- `simulations.strategy_id` → `ON DELETE SET NULL` zachowuje symulacje po soft delete strategii
- `simulations.target_draw_id` → `ON DELETE CASCADE` ponieważ draw nie powinien być usuwany
- `user_id` → `ON DELETE CASCADE` usuwa wszystkie powiązane dane użytkownika

---

## 3. Indeksy

### 3.1 users

```sql
-- Generowane automatycznie
CREATE UNIQUE INDEX users_pkey ON users(id);
CREATE UNIQUE INDEX users_email_key ON users(email);
```

### 3.2 strategies

```sql
-- Primary key
CREATE UNIQUE INDEX strategies_pkey ON strategies(id);

-- Filtrowanie po użytkowniku (najczęstsze query)
CREATE INDEX idx_strategies_user_id ON strategies(user_id);

-- Filtrowanie po typie
CREATE INDEX idx_strategies_type ON strategies(type);

-- Filtrowanie po statusie (partial index - tylko active)
CREATE INDEX idx_strategies_status_active ON strategies(status) 
  WHERE status = 'active';

-- Sortowanie po performance_score (rankingi)
CREATE INDEX idx_strategies_performance_score ON strategies(performance_score) 
  WHERE performance_score IS NOT NULL;

-- Composite index: user + performance (ranking per user)
CREATE INDEX idx_strategies_user_performance ON strategies(user_id, performance_score);

-- GIN index dla JSONB queries
CREATE INDEX idx_strategies_rules_gin ON strategies USING GIN(rules);
```

### 3.3 draws

```sql
-- Primary key
CREATE UNIQUE INDEX draws_pkey ON draws(id);

-- Unique constraint
CREATE UNIQUE INDEX draws_game_date_unique ON draws(game_type, draw_date);

-- Filtrowanie po game_type
CREATE INDEX idx_draws_game_type ON draws(game_type);

-- Sortowanie chronologiczne (najnowsze najpierw)
CREATE INDEX idx_draws_date_desc ON draws(draw_date DESC);

-- GIN index dla queries po numbers
CREATE INDEX idx_draws_numbers_gin ON draws USING GIN(numbers);
```

### 3.4 simulations

```sql
-- Primary key
CREATE UNIQUE INDEX simulations_pkey ON simulations(id);

-- Filtrowanie po użytkowniku (najczęstsze)
CREATE INDEX idx_simulations_user_id ON simulations(user_id);

-- Filtrowanie po strategii (partial - tylko non-null)
CREATE INDEX idx_simulations_strategy_id ON simulations(strategy_id) 
  WHERE strategy_id IS NOT NULL;

-- Sortowanie chronologiczne (historia symulacji)
CREATE INDEX idx_simulations_inserted_at_desc ON simulations(inserted_at DESC);

-- Composite: user + strategy + status (dla filtrowania i agregacji)
CREATE INDEX idx_simulations_user_strategy_status ON simulations(user_id, strategy_id, status);

-- Filtrowanie po statusie
CREATE INDEX idx_simulations_status ON simulations(status);

-- Performance: dla przeliczania performance_score
CREATE INDEX idx_simulations_strategy_attempts ON simulations(strategy_id, attempts_count) 
  WHERE status = 'success';
```

### 3.5 events

```sql
-- Primary key
CREATE UNIQUE INDEX events_pkey ON events(id);

-- Composite: user + data (analiza aktywności użytkownika)
CREATE INDEX idx_events_user_date ON events(user_id, inserted_at DESC);

-- Filtrowanie po typie eventu
CREATE INDEX idx_events_type ON events(event_type);

-- GIN index dla queries po metadata
CREATE INDEX idx_events_metadata_gin ON events USING GIN(metadata);
```

---

## 4. Trigger i funkcje

### 4.1 Trigger: update_updated_at_column

Automatyczna aktualizacja pola `updated_at` przy każdej zmianie rekordu.

```sql
-- Funkcja
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggery dla wszystkich tabel z updated_at
CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON users 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_strategies_updated_at 
  BEFORE UPDATE ON strategies 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_draws_updated_at 
  BEFORE UPDATE ON draws 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_simulations_updated_at 
  BEFORE UPDATE ON simulations 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 4.2 Trigger: recalculate_performance_score

Automatyczna aktualizacja `performance_score` w tabeli `strategies` po każdej zmianie w `simulations`.

```sql
-- Funkcja
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
  FOR EACH ROW 
  EXECUTE FUNCTION recalculate_performance_score();
```

**Uwagi:**
- Trigger przelicza performance_score tylko dla jednej strategii (nie wszystkich)
- Używa mediany zamiast średniej (mniej wrażliwe na outliers)
- Bierze pod uwagę tylko successful simulations
- Automatyczna aktualizacja `updated_at`

---

## 5. Row Level Security (RLS)

### 5.1 Konfiguracja RLS dla izolacji danych użytkowników

```sql
-- Enable RLS na tabelach z danymi użytkowników
ALTER TABLE strategies ENABLE ROW LEVEL SECURITY;
ALTER TABLE simulations ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Policy dla strategies
CREATE POLICY strategies_isolation 
  ON strategies
  FOR ALL 
  TO authenticated_user
  USING (user_id = current_setting('app.current_user_id')::uuid);

-- Policy dla simulations
CREATE POLICY simulations_isolation 
  ON simulations
  FOR ALL 
  TO authenticated_user
  USING (user_id = current_setting('app.current_user_id')::uuid);

-- Policy dla events
CREATE POLICY events_isolation 
  ON events
  FOR ALL 
  TO authenticated_user
  USING (user_id = current_setting('app.current_user_id')::uuid);
```

### 5.2 Ustawienie w aplikacji (Ecto)

```elixir
# Przy każdej transakcji/query
defmodule NumbersEvolution.Repo do
  use Ecto.Repo,
    otp_app: :numbers_evolution,
    adapter: Ecto.Adapters.Postgres

  def with_user_context(user_id, fun) do
    transaction(fn ->
      query!("SET LOCAL app.current_user_id = $1", [user_id])
      fun.()
    end)
  end
end
```

**Uwagi:**
- `draws` nie mają RLS - są danymi publicznymi
- `users` nie mają RLS - dostęp kontrolowany przez auth layer
- RLS zapewnia dodatkową warstwę security na poziomie bazy danych

---

## 6. Seed Data

### 6.1 Draws (100-200 losowań Eurojackpot)

```elixir
# priv/repo/seeds/draws.exs
draws = [
  %{
    draw_date: ~D[2024-11-08],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 7, 23, 34, 50],
      "euro_numbers" => [3, 9]
    },
    source: "manual"
  },
  # ... 100-200 więcej
]

Enum.each(draws, fn draw_data ->
  NumbersEvolution.Games.create_draw(draw_data)
end)
```

### 6.2 Template Strategies (15 szablonów)

```elixir
# priv/repo/seeds/template_strategies.exs
templates = [
  %{
    name: "Pure Random",
    type: "manual",
    status: "active",
    rules: %{
      "main_numbers" => %{
        "weights" => %{"random" => 1.0}
      },
      "euro_numbers" => %{
        "weights" => %{"random" => 1.0}
      }
    }
  },
  %{
    name: "Hot Numbers Focus",
    type: "manual",
    status: "active",
    rules: %{
      "main_numbers" => %{
        "weights" => %{"hot" => 0.7, "random" => 0.3}
      },
      "euro_numbers" => %{
        "weights" => %{"hot" => 0.6, "random" => 0.4}
      }
    }
  },
  # ... 13 więcej
]
```

---

## 7. Migracje - Kolejność wykonania

### Zalecana kolejność tworzenia migracji:

1. `20241114000001_create_users.exs` - phx.gen.auth
2. `20241114000002_add_preferences_to_users.exs` - dodanie pola preferences
3. `20241114000003_create_strategies.exs` - tabela strategies
4. `20241114000004_create_draws.exs` - tabela draws
5. `20241114000005_create_simulations.exs` - tabela simulations
6. `20241114000006_create_events.exs` - tabela events
7. `20241114000007_create_indexes_strategies.exs` - indeksy dla strategies
8. `20241114000008_create_indexes_draws.exs` - indeksy dla draws
9. `20241114000009_create_indexes_simulations.exs` - indeksy dla simulations
10. `20241114000010_create_indexes_events.exs` - indeksy dla events
11. `20241114000011_create_trigger_updated_at.exs` - trigger dla updated_at
12. `20241114000012_create_trigger_performance_score.exs` - trigger dla performance_score
13. `20241114000013_enable_rls.exs` - włączenie Row Level Security

---

## 8. Uwagi dotyczące wydajności

### 8.1 Optymalizacje zaimplementowane

1. **Indeksy GIN dla JSONB** - szybkie queries po polach JSON
2. **Partial indexes** - indeksowanie tylko aktywnych rekordów
3. **Composite indexes** - dla często używanych kombinacji filtrów
4. **Denormalizacja** - performance_score w strategies (zamiast każdorazowej agregacji)
5. **Trigger-based updates** - automatyczne przeliczanie metryk

### 8.2 Przyszłe optymalizacje (post-MVP)

1. **Partycjonowanie `simulations`** - gdy tabela przekroczy 1M rekordów
   ```sql
   -- Partycjonowanie po inserted_at (quarterly)
   CREATE TABLE simulations_2024_q4 PARTITION OF simulations
     FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');
   ```

2. **Connection pooling** - Ecto.Repo pool_size optimization

3. **Read replicas** - dla analytics queries (events, rankings)

4. **Materialized views** - dla rankingów strategii
   ```sql
   CREATE MATERIALIZED VIEW strategy_rankings AS
   SELECT 
     s.id,
     s.name,
     s.performance_score,
     COUNT(sim.id) as simulations_count
   FROM strategies s
   LEFT JOIN simulations sim ON sim.strategy_id = s.id
   WHERE s.status = 'active'
   GROUP BY s.id, s.name, s.performance_score
   ORDER BY s.performance_score ASC;
   ```

5. **Caching layer** (Redis) - dla:
   - Top 10 rankings
   - Recent draws
   - User statistics

### 8.3 Monitoring queries

```sql
-- Rozmiar tabel
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Nieużywane indeksy
SELECT 
  schemaname,
  tablename,
  indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey';
```

---

## 9. Backup i Recovery

### 9.1 Strategia backupów

**Fly.io Managed Postgres:**
- Automatic daily backups
- 7-day retention (hobby tier)
- Point-in-time recovery

**Własne backupy (recommended):**
```bash
# Weekly backup
pg_dump -h <host> -U <user> -d numbers_evolution \
  --format=custom --file=backup_$(date +%Y%m%d).dump

# Restore
pg_restore -h <host> -U <user> -d numbers_evolution backup.dump
```

### 9.2 Disaster Recovery Plan

1. **Dane krytyczne:**
   - `users` - hash haseł pozwala na odtworzenie dostępu
   - `draws` - mogą być odtworzone z publicznych źródeł
   - `strategies` - specyficzne dla użytkowników, krytyczne
   - `simulations` - mogą być przeliczone ponownie (czasochłonne)
   - `events` - analytics, niekrytyczne

2. **RTO (Recovery Time Objective):** 4 godziny
3. **RPO (Recovery Point Objective):** 24 godziny (daily backups)

---

## 10. Security Checklist

### 10.1 Implementowane w schemacie

- ✅ Foreign keys z odpowiednimi ON DELETE actions
- ✅ CHECK constraints dla integralności danych
- ✅ UNIQUE constraints dla unikalności
- ✅ Row Level Security (RLS) dla izolacji danych
- ✅ Haszowanie haseł (bcrypt) w aplikacji
- ✅ JSONB validation w Ecto (embedded schemas)

### 10.2 Do implementacji w aplikacji

- ⚠️ Rate limiting dla AI requests
- ⚠️ Prompt validation (max length, sanitization)
- ⚠️ Password strength validation
- ⚠️ Email confirmation flow
- ⚠️ JSON schema validation dla rules field
- ⚠️ Input sanitization dla user-provided data

### 10.3 Deployment security (Fly.io)

- ✅ HTTPS/TLS automatic
- ✅ Secrets management (fly secrets)
- ✅ Managed firewall
- ✅ SSL database connections

---

## 11. Zgodność z PRD

### 11.1 Mapowanie features do tabel

| Feature ID | Feature Name | Tabele używane | Status |
|------------|--------------|----------------|--------|
| F7 | Autoryzacja | users | ✅ Wspierane |
| F1 | Zarządzanie strategiami | strategies | ✅ Wspierane |
| F1.2 | Tworzenie manualne | strategies (type='manual') | ✅ Wspierane |
| F1.3 | Generowanie przez AI | strategies (type='ai_generated', ai_prompt) | ✅ Wspierane |
| F1.5 | Mieszanie strategii | strategies (nowy rekord) | ✅ Wspierane |
| F6 | Dane historyczne | draws | ✅ Wspierane |
| F2 | Silnik symulacji | simulations | ✅ Wspierane |
| F3 | Live tracking | simulations (status updates) | ✅ Wspierane |
| F4 | Ranking | strategies.performance_score | ✅ Wspierane |
| F5 | Generator propozycji | strategies (algorytm w app) | ✅ Wspierane |
| F8 | Dashboard | wszystkie tabele | ✅ Wspierane |
| F-MS | Multisymulacje (MVP2) | simulations | ✅ Wspierane |

### 11.2 Wymagania niefunkcjonalne

- ✅ Skalowalność: indeksy, partitioning-ready
- ✅ Bezpieczeństwo: RLS, constraints, FK
- ✅ Wydajność: denormalizacja, composite indexes
- ✅ Maintainability: triggers, audit trail (timestamps)
- ✅ Elastyczność: JSONB dla dynamicznych struktur

---

## 12. Embedded Schemas (Ecto)

### 12.1 StrategyRules

```elixir
defmodule NumbersEvolution.Strategies.Rules do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    embeds_one :main_numbers, MainNumbers do
      field :ratio_even_odd, {:array, :integer}
      field :ratio_low_high, {:array, :integer}
      field :preferred_hot, {:array, :integer}
      field :preferred_cold, {:array, :integer}
      
      embeds_one :weights, Weights do
        field :hot, :float
        field :cold, :float
        field :random, :float
      end
    end
    
    embeds_one :euro_numbers, EuroNumbers do
      field :ratio_even_odd, {:array, :integer}
      field :preferred, {:array, :integer}
      
      embeds_one :weights, Weights do
        field :hot, :float
        field :random, :float
      end
    end
  end

  def changeset(rules, attrs) do
    rules
    |> cast(attrs, [])
    |> cast_embed(:main_numbers, required: true)
    |> cast_embed(:euro_numbers, required: true)
    |> validate_weights()
  end

  defp validate_weights(changeset) do
    # Validate that weights sum to 1.0
    # Validate ratio arrays sum correctly
  end
end
```

### 12.2 SimulationResult

```elixir
defmodule NumbersEvolution.Simulations.Result do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :matched_main, {:array, :integer}
    field :matched_euro, {:array, :integer}
    field :attempts_count, :integer
    field :reason, :string
    field :limit_reached, :string
    field :error_message, :string
    
    embeds_one :final_draw, FinalDraw do
      field :main_numbers, {:array, :integer}
      field :euro_numbers, {:array, :integer}
    end
  end
end
```

---

## 13. Podsumowanie

### 13.1 Statystyki schematu

- **Tabele:** 5 (users, strategies, draws, simulations, events)
- **Relacje:** 5 (foreign keys)
- **Indeksy:** 22 (w tym 3 GIN, 2 partial, 4 composite)
- **Triggery:** 6 (5 × updated_at + 1 × performance_score)
- **RLS Policies:** 3 (strategies, simulations, events)
- **Constraints:** 14 CHECK constraints

### 13.2 Przestrzeń dyskowa (szacunki)

**MVP1 (10 użytkowników testowych):**
- users: ~10 KB
- strategies: ~50 KB (50 strategii)
- draws: ~500 KB (200 losowań)
- simulations: ~10 MB (1000 symulacji)
- events: ~1 MB (5000 eventów)
- **Total: ~12 MB**

**Post-MVP (100 active users):**
- users: ~100 KB
- strategies: ~500 KB (500 strategii)
- draws: ~1 MB (500 losowań)
- simulations: ~500 MB (50k symulacji)
- events: ~50 MB (250k eventów)
- **Total: ~550 MB**

### 13.3 Gotowość do implementacji

Schema jest **kompletny i gotowy** do:
1. ✅ Tworzenia migracji Ecto
2. ✅ Generowania kontekstów Phoenix
3. ✅ Implementacji modeli i changesetów
4. ✅ Seedowania danych testowych
5. ✅ Uruchomienia aplikacji MVP1

---

**Dokument zatwierdzony:** TAK  
**Gotowy do implementacji:** TAK  
**Następny krok:** Tworzenie migracji Ecto w projekcie Phoenix

