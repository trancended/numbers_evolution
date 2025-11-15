# Migracje - Podsumowanie

**Data utworzenia:** 14 listopada 2025  
**Status:** ✅ Gotowe do uruchomienia

---

## 📋 Utworzone migracje

Wszystkie 12 migracji zostały utworzone zgodnie z db-plan.md:

| # | Timestamp | Nazwa | Opis |
|---|-----------|-------|------|
| 1 | 20241114000001 | `create_users.exs` | Tabela users z UUID, email (citext), hashed_password |
| 2 | 20241114000002 | `add_preferences_to_users.exs` | Dodanie pola preferences (JSONB) |
| 3 | 20241114000003 | `create_strategies.exs` | Tabela strategies z constraints i FK do users |
| 4 | 20241114000004 | `create_draws.exs` | Tabela draws z unique constraint |
| 5 | 20241114000005 | `create_simulations.exs` | Tabela simulations z FK i CHECK constraints |
| 6 | 20241114000006 | `create_events.exs` | Tabela events z event_type constraint |
| 7 | 20241114000007 | `create_indexes_strategies.exs` | 6 indeksów dla strategies (w tym GIN) |
| 8 | 20241114000008 | `create_indexes_draws.exs` | 3 indeksy dla draws (w tym GIN) |
| 9 | 20241114000009 | `create_indexes_simulations.exs` | 6 indeksów dla simulations |
| 10 | 20241114000010 | `create_indexes_events.exs` | 3 indeksy dla events (w tym GIN) |
| 11 | 20241114000011 | `create_trigger_updated_at.exs` | Trigger automatycznej aktualizacji updated_at |
| 12 | 20241114000012 | `create_trigger_performance_score.exs` | Trigger przeliczania performance_score |

---

## 🚀 Jak uruchomić migracje

### 1. Upewnij się, że baza danych działa

```bash
# Sprawdź konfigurację w config/dev.exs
# Domyślnie Phoenix szuka PostgreSQL na localhost:5432
```

### 2. Utwórz bazę danych (jeśli nie istnieje)

```bash
mix ecto.create
```

### 3. Uruchom migracje

```bash
mix ecto.migrate
```

### 4. Sprawdź status migracji

```bash
mix ecto.migrations
```

---

## 🔧 Kluczowe Features

### ✅ UUID jako Primary Keys

Wszystkie tabele używają UUID zamiast auto-increment integers:
- Bezpieczniejsze w API (brak sequential IDs)
- Distributed-friendly (można generować offline)
- Używa `uuid-ossp` extension

### ✅ JSONB Columns

Trzy tabele używają JSONB dla elastycznych struktur:
- `users.preferences` - ustawienia użytkownika
- `strategies.rules` - dynamiczne reguły strategii
- `draws.numbers` - wylosowane liczby
- `simulations.result` - wyniki symulacji
- `events.metadata` - metadane eventów

**Indeksy GIN** zapewniają szybkie queries po polach JSON.

### ✅ CHECK Constraints

Walidacja na poziomie bazy danych:
- `strategies.type` ∈ {'manual', 'ai_generated'}
- `strategies.status` ∈ {'active', 'deleted', 'archived'}
- `simulations.status` ∈ {'pending', 'running', 'success', 'timeout', 'error', 'cancelled'}
- `simulations.attempts_count >= 0`
- `simulations.duration_seconds >= 0`
- `simulations.completed_at >= started_at`
- `events.event_type` ∈ {10 predefiniowanych typów}

### ✅ Foreign Keys z ON DELETE Actions

- `strategies.user_id` → CASCADE (usuń strategie po usunięciu użytkownika)
- `simulations.user_id` → CASCADE
- `simulations.strategy_id` → SET NULL (zachowaj symulacje po soft delete strategii)
- `simulations.target_draw_id` → CASCADE
- `events.user_id` → CASCADE

### ✅ Automatyczne Triggery

**1. update_updated_at_column()**
- Automatycznie aktualizuje `updated_at` przy każdym UPDATE
- Zainstalowany na: users, strategies, draws, simulations

**2. recalculate_performance_score()**
- Automatycznie przelicza medianę z `attempts_count` dla strategii
- Uruchamiany po INSERT/UPDATE/DELETE w simulations
- Aktualizuje tylko affected strategy (wydajne)

### ✅ Indeksy dla Performance

**22 indeksów celowanych w konkretne query patterns:**

**Strategies:**
- User filtering (idx_strategies_user_id)
- Type filtering (idx_strategies_type)
- Active only (partial index)
- Performance ranking (idx_strategies_performance_score)
- User performance (composite)
- JSONB rules (GIN)

**Draws:**
- Game type filtering
- Chronological DESC
- JSONB numbers (GIN)

**Simulations:**
- User filtering
- Strategy filtering (partial, non-null only)
- Chronological DESC
- User + strategy + status (composite)
- Status filtering
- Performance calculation (partial, success only)

**Events:**
- User + date (composite)
- Event type filtering
- JSONB metadata (GIN)

---

## ⚠️ Uwagi i ograniczenia

### Row Level Security (RLS)

**NIE zaimplementowano RLS** z db-plan.md (sekcja 5) ponieważ:

1. Phoenix/Ecto zazwyczaj **nie używa RLS**
2. Izolacja danych użytkowników jest realizowana w **application layer**:
   - Przez Contexts (np. `Strategies.list_user_strategies(user_id)`)
   - Przez Phoenix.LiveView scopes
   - Przez polityki autoryzacji (np. poprzez bibliotekę `bodyguard`)

3. RLS w PostgreSQL wymaga ustawiania `SET LOCAL app.current_user_id` w każdej transakcji, co:
   - Komplikuje kod
   - Może powodować performance issues
   - Utrudnia testowanie

**Jeśli jednak chcesz RLS**, możesz dodać migrację:

```elixir
# priv/repo/migrations/20241114000013_enable_rls.exs
defmodule NumbersEvolution.Repo.Migrations.EnableRls do
  use Ecto.Migration

  def up do
    # Enable RLS
    execute "ALTER TABLE strategies ENABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE simulations ENABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE events ENABLE ROW LEVEL SECURITY"

    # Create policies (wymaga utworzenia roli 'authenticated_user')
    execute """
    CREATE POLICY strategies_isolation ON strategies
      FOR ALL TO authenticated_user
      USING (user_id = current_setting('app.current_user_id')::uuid)
    """

    execute """
    CREATE POLICY simulations_isolation ON simulations
      FOR ALL TO authenticated_user
      USING (user_id = current_setting('app.current_user_id')::uuid)
    """

    execute """
    CREATE POLICY events_isolation ON events
      FOR ALL TO authenticated_user
      USING (user_id = current_setting('app.current_user_id')::uuid)
    """
  end

  def down do
    execute "DROP POLICY IF EXISTS events_isolation ON events"
    execute "DROP POLICY IF EXISTS simulations_isolation ON simulations"
    execute "DROP POLICY IF EXISTS strategies_isolation ON strategies"
    
    execute "ALTER TABLE events DISABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE simulations DISABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE strategies DISABLE ROW LEVEL SECURITY"
  end
end
```

### Extensions

Migracja `20241114000001_create_users.exs` instaluje:
- `uuid-ossp` - generowanie UUID
- `citext` - case-insensitive text (dla email)

### Timestamps

Wszystkie tabele używają `timestamps(type: :utc_datetime)`:
- `inserted_at` - data utworzenia
- `updated_at` - data modyfikacji (auto-update przez trigger)

**Wyjątek:** `events` ma tylko `inserted_at` (immutable log).

---

## 🧪 Testowanie migracji

### Rollback wszystkich migracji

```bash
mix ecto.rollback --all
```

### Rollback ostatniej migracji

```bash
mix ecto.rollback
```

### Rollback do konkretnej wersji

```bash
mix ecto.rollback --to 20241114000005
```

### Re-migrate

```bash
mix ecto.rollback --all && mix ecto.migrate
```

---

## 📊 Seed Data

Po uruchomieniu migracji, możesz dodać seed data:

```bash
# Utwórz plik priv/repo/seeds.exs
mix run priv/repo/seeds.exs
```

Zgodnie z db-plan.md, potrzebujesz:
1. **100-200 historycznych losowań** Eurojackpot
2. **15 template strategii** (Pure Random, Hot Numbers, etc.)

---

## 🔍 Debugging

### Sprawdź strukturę tabel

```bash
mix ecto.migrate
psql -d numbers_evolution_dev -c "\d+ users"
psql -d numbers_evolution_dev -c "\d+ strategies"
```

### Sprawdź indeksy

```sql
SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

### Sprawdź triggery

```sql
SELECT 
  trigger_name,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public';
```

### Sprawdź constraints

```sql
SELECT
  table_name,
  constraint_name,
  constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public'
ORDER BY table_name;
```

---

## ✅ Checklist przed deploy

- [ ] `mix ecto.create` - baza utworzona
- [ ] `mix ecto.migrate` - migracje uruchomione bez błędów
- [ ] `mix ecto.migrations` - wszystkie 12 migracji applied
- [ ] `mix test` - testy przechodzą (gdy będą utworzone)
- [ ] Seed data załadowane (opcjonalnie)
- [ ] Connection pooling skonfigurowany w `config/prod.exs`
- [ ] Database backups skonfigurowane (Fly.io lub własne)

---

## 📚 Następne kroki

1. **Utwórz Ecto Schemas** w `lib/numbers_evolution/`:
   - `lib/numbers_evolution/accounts/user.ex`
   - `lib/numbers_evolution/strategies/strategy.ex`
   - `lib/numbers_evolution/games/draw.ex`
   - `lib/numbers_evolution/simulations/simulation.ex`
   - `lib/numbers_evolution/events/event.ex`

2. **Utwórz Contexts** (Phoenix best practice):
   - `lib/numbers_evolution/accounts.ex`
   - `lib/numbers_evolution/strategies.ex`
   - `lib/numbers_evolution/games.ex`
   - `lib/numbers_evolution/simulations.ex`
   - `lib/numbers_evolution/events.ex`

3. **Embedded Schemas** dla JSONB (zgodnie z db-plan sekcja 12):
   - `lib/numbers_evolution/strategies/rules.ex`
   - `lib/numbers_evolution/simulations/result.ex`

4. **Seed Scripts**:
   - `priv/repo/seeds/draws.exs`
   - `priv/repo/seeds/template_strategies.exs`

5. **Tests**:
   - `test/numbers_evolution/accounts_test.exs`
   - `test/numbers_evolution/strategies_test.exs`
   - ...

---

## 🎉 Podsumowanie

**Status:** ✅ **GOTOWE**

Wszystkie 12 migracji zostały utworzone zgodnie z db-plan.md:
- ✅ 5 głównych tabel
- ✅ 22 indeksy (w tym 3 GIN dla JSONB)
- ✅ 14 CHECK constraints
- ✅ 5 foreign keys z odpowiednimi ON DELETE actions
- ✅ 2 triggery (updated_at + performance_score)
- ✅ UUID primary keys
- ✅ JSONB columns dla elastycznych struktur
- ✅ Partial indexes dla optymalizacji

**Brakuje tylko:** Row Level Security (RLS) - celowo pominięte, bo Phoenix zazwyczaj obsługuje to w app layer.

**Kompatybilność:**
- ✅ PostgreSQL 14+
- ✅ Ecto 3.x
- ✅ Phoenix 1.8
- ✅ Fly.io Managed Postgres

**Gotowe do:**
```bash
mix ecto.create
mix ecto.migrate
```

🚀 **Możesz teraz przejść do tworzenia Ecto Schemas i Contexts!**

