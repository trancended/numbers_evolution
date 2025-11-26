# Instrukcje Deployment na Fly.io

## Problem z `fly launch`
NIE używaj `fly launch` - próbuje automatycznie generować konfigurację, która już istnieje!

## Poprawna procedura:

### 1. Sprawdź czy aplikacja istnieje
```bash
fly apps list | grep numbers-evolution-akkdua
```

### 2. Jeśli aplikacja NIE istnieje, utwórz ją:
```bash
fly apps create numbers-evolution-akkdua
```
*(bez `--org personal` jeśli masz problem z organizacją)*

### 3. Utwórz i podłącz bazę danych PostgreSQL:
```bash
# Utwórz bazę (dedicated-cpu-1x dla produkcji)
fly postgres create --name numbers-evolution-db --region fra --initial-cluster-size 1 --vm-size dedicated-cpu-1x

# WAŻNE: Zapisz dane logowania!
# Username: postgres
# Password: dc4WHGKaC2s9LKm
# Hostname: numbers-evolution-db.internal
# Connection string: postgres://postgres:dc4WHGKaC2s9LKm@numbers-evolution-db.flycast:5432
```

### 4. Ustaw sekrety:
```bash
# Wygeneruj secret key
SECRET_KEY=$(mix phx.gen.secret)
echo "SECRET_KEY_BASE: $SECRET_KEY"

# Ustaw sekrety (UWAGA: DATABASE_URL musi zawierać nazwę bazy!)
fly secrets set SECRET_KEY_BASE="ZFuK7KK5hEOldSdUCl737DghI0/7wCAM1fKeWRa+BNFYfpPxUabKtD/T/NgSX3Wd" -a numbers-evolution-akkdua

fly secrets set DATABASE_URL="postgres://postgres:dc4WHGKaC2s9LKm@numbers-evolution-db.flycast:5432/numbers_evolution_prod" -a numbers-evolution-akkdua

fly secrets set OPENROUTER_API_KEY="twój_klucz_z_openrouter" -a numbers-evolution-akkdua
```

**WAŻNE:** DATABASE_URL musi zawierać nazwę bazy na końcu (`/numbers_evolution_prod` lub `/postgres`)

### 5. Deploy aplikacji:
```bash
fly deploy -a numbers-evolution-akkdua
```

### 6. Weryfikacja:
```bash
# Status
fly status -a numbers-evolution-akkdua

# Logi
fly logs -a numbers-evolution-akkdua

# Otwórz w przeglądarce
fly open -a numbers-evolution-akkdua
```

## Troubleshooting:

### Błąd: "app not found"
```bash
fly apps create numbers-evolution-akkdua
```

### Błąd: "DATABASE_URL not set" lub "invalid URL"
Upewnij się, że DATABASE_URL zawiera nazwę bazy:
```bash
fly secrets set DATABASE_URL="postgres://postgres:PASSWORD@numbers-evolution-db.flycast:5432/numbers_evolution_prod" -a numbers-evolution-akkdua
```

### Błąd: "Could not create schema migrations table"
Baza danych nie istnieje. Skrypt migracji powinien ją automatycznie utworzyć, ale możesz też:
```bash
# Połącz się z bazą i utwórz ją ręcznie
fly postgres connect -a numbers-evolution-db
# W psql:
CREATE DATABASE numbers_evolution_prod;
\q
```

### Błąd: "force_ssl compile time vs runtime"
Upewnij się, że `force_ssl` jest ustawione w `config/prod.exs`, nie w `config/runtime.exs`

### Sprawdź sekrety:
```bash
fly secrets list -a numbers-evolution-akkdua
```

## Konfiguracja PostgreSQL:

### Dla developmentu/testów:
- **shared-cpu-1x**: 1 współdzielony CPU, 512MB RAM (~$0.04/h)

### Dla produkcji (zalecane):
- **dedicated-cpu-1x**: 1 dedykowany CPU, 1GB RAM (~$0.10/h)
- **dedicated-cpu-2x**: 2 dedykowane CPU, 2GB RAM (~$0.20/h)

## Autoryzacja Fly.io:

Jeśli masz problemy z autoryzacją CLI:
```bash
# Wyloguj się
fly auth logout

# Usuń token ze zmiennych środowiskowych
unset FLY_ACCESS_TOKEN

# Zaloguj się ponownie przez przeglądarkę
fly auth login
```

Alternatywnie możesz wszystko zrobić przez panel webowy: https://fly.io/apps
