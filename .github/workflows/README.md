# GitHub Actions Workflows

## Przegląd

Projekt wykorzystuje zestaw zautomatyzowanych workflow CI/CD zapewniających wysoką jakość kodu i niezawodne wdrożenia.

## Workflows

### 1. CI Pipeline (`ci.yml`) - Main Branch Only

**Trigger:** Push do brancha `main` (po merge PR)

**Joby:**
- **Test** - Testy jednostkowe i sprawdzanie formatowania
- **E2E** - Testy end-to-end z użyciem Cypress (**TYLKO na main branch**)

**Kroki:**
1. Setup Elixir i Node.js
2. Instalacja zależności
3. Sprawdzenie formatowania kodu
4. Kompilacja z błędami jako ostrzeżeniami
5. Uruchomienie testów jednostkowych
6. Uruchomienie testów E2E (jeśli unit testy przejdą)

**Note:** E2E testy uruchamiają się TYLKO na main branch dla oszczędności czasu.

### 2. Pull Request Checks (`pull-request.yml`) - Fast Feedback

**Trigger:** Pull Request do brancha `main`

**Joby:**
- **Lint** - Linting i kompilacja
- **Unit Test** - Testy jednostkowe
- **Status Comment** - Komentarz ze statusem wszystkich checks

**Funkcje:**
- ⚡ **Szybka walidacja** - tylko unit testy dla natychmiastowego feedbacku
- Automatyczne komentarze z wynikami CI
- E2E testy **pominięte** - uruchomią się po merge do main
- Szczegółowy status każdego joba

### 3. Master Branch Quality Gate (`master.yml`)

**Trigger:** Push do brancha `master`

**Joby:**
- **Quality Check** - Kompletna weryfikacja jakości
- **Status Notification** - Powiadomienie o statusie

**Sprawdzenia:**
- Formatowanie kodu
- Kompilacja
- Linting (Credo)
- Wszystkie testy
- Pre-commit hooks

### 4. Deployment Pipeline (`deploy.yml`)

**Trigger:** 
- Push do brancha `master`
- Ręczne uruchomienie (workflow_dispatch)

**Joby:**
1. **Quality Gate** - Pre-deployment quality checks
2. **Deploy** - Wdrożenie na Fly.io
3. **Verify Deployment** - Weryfikacja poprawności wdrożenia

**Proces:**
1. Uruchomienie testów i sprawdzenie jakości
2. Deploy aplikacji na Fly.io
3. Automatyczne uruchomienie migracji bazy danych
4. Health check aplikacji
5. Powiadomienie o statusie

### 5. E2E Tests (`e2e.yml`) - Manual Trigger

**Trigger:** Tylko ręczne uruchomienie (`workflow_dispatch`)

**Funkcje:**
- 🎯 **On-demand testing** - uruchamiaj E2E kiedy potrzebujesz
- Kompleksowe testy end-to-end z Cypress
- Automatyczne nagrywanie wideo z testów
- Screenshoty przy błędach
- Reset bazy danych przed testami

**Kiedy używać:**
- Testowanie przed ważnym release
- Weryfikacja krytycznych zmian w UI
- Debugowanie problemów E2E
- Nie uruchamia się automatycznie dla oszczędności czasu CI

## Reusable Actions

Projekt zawiera wielokrotnego użytku akcje w `.github/actions/`:

### setup-elixir
Konfiguruje środowisko Elixir, cache'uje zależności i instaluje pakiety.

**Inputs:**
- `elixir-version` - wersja Elixir (default: 1.19.3)
- `otp-version` - wersja OTP (default: 28.1)
- `mix-env` - środowisko Mix (default: test)
- `cache-deps` - czy cache'ować zależności (default: true)

### setup-database
Tworzy i migruje bazę danych testową.

**Inputs:**
- `mix-env` - środowisko Mix
- `database-url` - URL bazy danych

### quality-checks
Uruchamia wszystkie sprawdzenia jakości kodu.

**Inputs:**
- `mix-env` - środowisko Mix
- `database-url` - URL bazy danych (opcjonalny)
- `run-credo` - czy uruchomić Credo (default: true)
- `run-tests` - czy uruchomić testy (default: true)
- `run-precommit` - czy uruchomić pre-commit (default: false)

## Konfiguracja Secrets

### Wymagane GitHub Secrets

1. **FLY_API_TOKEN**
   - Token autoryzacyjny Fly.io
   - Wymagany do deployment
   - Uzyskaj przez: `fly auth token`

2. **OPENROUTER_API_KEY** (opcjonalny)
   - Klucz API do OpenRouter
   - Używany w testach E2E
   - Jeśli nie ustawiony, użyty zostanie dummy key

### Ustawianie Secrets

1. Przejdź do Settings → Secrets and variables → Actions
2. Kliknij "New repository secret"
3. Dodaj wymagane sekrety

## Strategie Cachowania

Wszystkie workflows wykorzystują cache dla:
- **Mix dependencies** - cache bazowany na `mix.lock`
- **Build artifacts** - cache `_build` directory
- **Node modules** - cache bazowany na `package-lock.json` (dla E2E)

Cache key: `${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}`

## Debugging

### Wyświetlenie logów workflow
1. Przejdź do zakładki "Actions"
2. Wybierz workflow run
3. Kliknij na job, który chcesz zbadać

### Pobranie artefaktów
Artefakty (wideo, screenshoty, logi) są dostępne przez 7 dni po uruchomieniu workflow.

### Uruchomienie workflow ręcznie
Workflow `deploy.yml` można uruchomić ręcznie:
1. Przejdź do Actions → Deploy to Fly.io
2. Kliknij "Run workflow"
3. Wybierz branch
4. Kliknij "Run workflow"

## Best Practices

1. **Zawsze** sprawdzaj status CI przed mergem PR
2. **Nigdy** nie pushuj bezpośrednio do `master` - używaj PR
3. **Monitoruj** deployment pipeline po merge do master
4. **Przeglądaj** logi w przypadku błędów
5. **Aktualizuj** wersje akcji regularnie

## 🚀 Optymalizacja Workflow E2E

Aby przyspieszyć feedback w PR:
- **Pull Requests**: Uruchamiają tylko unit testy (~2-3 min)
- **Main Branch**: Uruchamia pełne testy z E2E (~10-15 min)
- **Manual E2E**: Dostępne przez Actions → E2E Tests (Manual) → Run workflow

To podejście daje:
- ⚡ Szybki feedback podczas development (unit testy)
- 🛡️ Pełna walidacja przed deployment (E2E na main)
- 💰 Oszczędność czasu CI (E2E nie uruchamiają się 3x dla każdego PR)

## Troubleshooting

### CI fails on database connection
- Sprawdź, czy port PostgreSQL nie jest zajęty
- Workflow zawiera cleanup step, który powinien rozwiązać większość problemów

### E2E tests timeout
- Zwiększ timeout w `cypress.config.js`
- Sprawdź logi Phoenix servera w artefaktach

### Deployment fails
- Sprawdź, czy `FLY_API_TOKEN` jest poprawnie ustawiony
- Zweryfikuj, czy aplikacja Fly.io istnieje
- Zobacz logi deployment w Actions

### Cache issues
Jeśli podejrzewasz problemy z cache:
1. Usuń cache w Settings → Actions → Caches
2. Re-run workflow

## Monitoring

### Metryki CI/CD
- Czas wykonania workflows
- Wskaźnik sukcesu
- Częstotliwość deploymentów

### Alerty
Wszystkie failed workflows generują notifications w GitHub.

## Aktualizacje

Przy aktualizacji workflow:
1. Testuj zmiany na osobnym branchu
2. Uruchom workflow ręcznie przed mergem
3. Monitoruj pierwsze uruchomienie po merge

