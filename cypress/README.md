# E2E Tests - Numbers Evolution

Kompleksowe testy end-to-end dla aplikacji Numbers Evolution używające Cypress.

## Wymagania wstępne

- Node.js 16+
- Elixir 1.14+
- PostgreSQL 14+
- Zainstalowane zależności: `npm install`

## Uruchamianie testów

### 1. Przygotowanie środowiska

```bash
# Upewnij się, że PostgreSQL jest uruchomiony
# Na macOS z Homebrew:
brew services start postgresql

# Albo użyj Docker:
docker run --name postgres-e2e -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:14
```

### 2. Uruchomienie aplikacji w trybie E2E

```bash
# W pierwszym terminalu - uruchom Phoenix server
MIX_ENV=test_e2e mix phx.server
```

### 3. Uruchomienie testów Cypress

```bash
# W drugim terminalu - uruchom testy
npm run cypress:run

# Lub uruchom w trybie interaktywnym
npm run cypress:open
```

## Struktura testów

```
cypress/
├── e2e/                    # Testy E2E
│   ├── auth.cy.js         # Testy rejestracji i logowania
│   ├── strategies.cy.js   # Testy zarządzania strategiami
│   └── simulations.cy.js  # Testy symulacji
├── fixtures/              # Statyczne dane testowe
├── support/               # Wspólne funkcje
│   ├── commands.js        # Custom Cypress commands
│   └── e2e.js            # Globalna konfiguracja
└── README.md             # Ten plik
```

## Baza danych testowa

Testy używają dedykowanej bazy danych `numbers_evolution_test_e2e`, która jest automatycznie resetowana przed każdym testem.

```bash
# Ręczne zarządzanie bazą E2E
MIX_ENV=test_e2e mix e2e_db reset    # Resetuj bazę (drop, create, migrate, seed)
MIX_ENV=test_e2e mix e2e_db seed     # Tylko seed danych
MIX_ENV=test_e2e mix e2e_db help     # Pokaż dostępne komendy
```

## Custom Commands

### Authentication
```javascript
cy.login('test@example.com', 'testpassword123')  // Zaloguj użytkownika
```

### Strategies
```javascript
cy.createAIStrategy('Test Strategy')  // Utwórz strategię przez AI
```

### Simulations
```javascript
cy.runSimulation(0, 0)  // Uruchom symulację (strategy_index, target_draw_index)
cy.waitForSimulationComplete(60000)  // Czekaj na zakończenie symulacji
```

## Data-cy Attributes

Testy używają atrybutów `data-cy` dla stabilnej identyfikacji elementów:

```html
<!-- Przykład -->
<button data-cy="register-button" phx-click="show_register_form">
  Zarejestruj się
</button>
```

## Specyfika Phoenix LiveView

### Czekanie na LiveView mount
```javascript
cy.visit('/')
cy.window().its('liveSocket').should('exist')  // Zawsze czekaj na LiveView
```

### Real-time updates
```javascript
// Symulacje mogą trwać długo - zwiększ timeout
cy.get('[data-cy="simulation-status"]', { timeout: 60000 })
  .should('contain', 'Zakończona')
```

### Modals w DaisyUI
```javascript
cy.get('[data-cy="register-modal"]').should('be.visible')
cy.get('.modal.modal-open').should('exist')
```

## Troubleshooting

### Problemy z bazą danych
```bash
# Sprawdź czy PostgreSQL działa
psql -h localhost -U postgres

# Resetuj bazę manualnie
MIX_ENV=test_e2e mix e2e_db reset
```

### Problemy z Cypress
```bash
# Wyczyść cache Cypress
npx cypress cache clear

# Uruchom w trybie debug
npm run cypress:open
```

### Problemy z LiveView
- Upewnij się, że `MIX_ENV=test_e2e` jest ustawiony
- Sprawdź czy Phoenix server nasłuchuje na porcie 4000
- Symulacje mogą trwać długo - zwiększ timeout w testach

## CI/CD

Testy są skonfigurowane do uruchamiania w GitHub Actions:

```yaml
# .github/workflows/e2e.yml
- name: Setup test database
  run: |
    MIX_ENV=test_e2e mix ecto.create
    MIX_ENV=test_e2e mix ecto.migrate
    MIX_ENV=test_e2e mix run priv/repo/seeds.exs
- name: Run Phoenix server
  run: MIX_ENV=test_e2e mix phx.server
  background: true
- name: Run E2E tests
  run: npx cypress run
```

## Debugowanie

### Wizualne debugowanie
```javascript
cy.pause()  // Zatrzymaj test w danym miejscu
cy.debug()  // Dodaj breakpoint
```

### Logowanie
```javascript
cy.window().then((win) => {
  cy.spy(win.console, 'log')  // Śledź logi przeglądarki
})
```

### Screenshot przy błędach
Cypress automatycznie robi screenshot przy niepowodzeniach w katalogu `cypress/screenshots/`.

## Pokrycie testowe

| Obszar | Status | Opis |
|--------|--------|------|
| **Rejestracja** | ✅ | Rejestracja, walidacja, błędy |
| **Logowanie** | ✅ | Logowanie, błędne dane, wylogowanie |
| **Strategie AI** | ✅ | Tworzenie przez AI, templates, zapis |
| **Symulacje** | ✅ | Uruchamianie, śledzenie postępów, historia |
| **Dashboard** | ⚠️ | Podstawowe testy nawigacji |
| **Ranking** | ❌ | Nie zaimplementowane |
| **Generator** | ❌ | Nie zaimplementowane |
| **API** | ❌ | Nie zaimplementowane |

## Rozwój

### Dodawanie nowych testów

1. Utwórz plik w `cypress/e2e/`
2. Użyj `data-cy` attributes dla elementów
3. Dodaj odpowiednie `beforeEach` hooks
4. Wykorzystaj custom commands

### Dodawanie data-cy attributes

W komponentach dodawaj atrybuty `data-cy` do kluczowych elementów:

```heex
<button data-cy="create-strategy-btn" phx-click="open_strategy_form">
  Nowa strategia
</button>
```

---

**Status:** ✅ Gotowe do uruchomienia
**Ostatnia aktualizacja:** Listopad 2025
