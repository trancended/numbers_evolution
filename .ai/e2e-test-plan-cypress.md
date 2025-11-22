# Plan Testów E2E - Numbers Evolution (Cypress + Test Database)

## 🎯 Przegląd

Kompleksowy plan testów end-to-end dla aplikacji Numbers Evolution używający Cypress z dedykowaną bazą testową PostgreSQL. Testy będą pokrywać wszystkie kluczowe funkcjonalności aplikacji Phoenix LiveView.

## 🏗 Infrastruktura Testowa

### Baza Danych Testowa
- **Nazwa bazy**: `numbers_evolution_test_e2e`
- **Izolacja**: Oddzielna baza od `numbers_evolution_test`
- **Seed data**: Pełne dane historyczne Eurojackpot (~200 losowań)
- **Cleanup**: Automatyczne czyszczenie między testami

### Konfiguracja Cypress
```javascript
// cypress.config.js
export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:4000',
    specPattern: 'cypress/e2e/**/*.cy.js',
    supportFile: 'cypress/support/e2e.js',
    viewportWidth: 1280,
    viewportHeight: 720,
    video: true,
    screenshotOnRunFailure: true,
    retries: {
      runMode: 2,
      openMode: 1,
    },
    env: {
      API_BASE_URL: 'http://localhost:4000/api',
      TEST_USER_EMAIL: 'test@example.com',
      TEST_USER_PASSWORD: 'testpassword123',
    }
  }
})
```

### Środowisko Testowe
```bash
# Uruchomienie testów E2E
MIX_ENV=test_e2e mix phx.server
# W osobnym terminalu
npm run cypress:run
```

### Przygotowanie Aplikacji do Testów

**Dodane atrybuty `data-cy` do kluczowych elementów:**

**Landing Page:**
- `data-cy="register-button"` - przycisk rejestracji
- `data-cy="login-button"` - przycisk logowania

**Modals:**
- `data-cy="register-modal"` - modal rejestracji
- `data-cy="register-form"` - formularz rejestracji
- `data-cy="register-submit"` - przycisk rejestracji
- `data-cy="register-cancel"` - przycisk anulowania rejestracji
- `data-cy="login-modal"` - modal logowania
- `data-cy="login-form"` - formularz logowania
- `data-cy="login-submit"` - przycisk logowania
- `data-cy="login-cancel"` - przycisk anulowania logowania

**Nawigacja:**
- `data-cy="nav-dashboard"` - przycisk Dashboard
- `data-cy="nav-strategies"` - przycisk Strategie
- `data-cy="nav-simulations"` - przycisk Symulacje
- `data-cy="nav-ranking"` - przycisk Ranking
- `data-cy="nav-generator"` - przycisk Generator
- `data-cy="user-menu"` - menu użytkownika
- `data-cy="logout-button"` - przycisk wylogowania

**Dashboard:**
- `data-cy="quick-create-strategy"` - szybkie utworzenie strategii
- `data-cy="quick-run-simulation"` - szybkie uruchomienie symulacji
- `data-cy="quick-generate-coupons"` - szybkie generowanie kuponów

**Strategie:**
- `data-cy="create-strategy-btn"` - przycisk nowej strategii
- `data-cy="strategy-form-modal"` - modal formularza
- `data-cy="ai-tab"` - zakładka AI
- `data-cy="manual-tab"` - zakładka Manualna
- `data-cy="generate-strategy-btn"` - przycisk generowania strategii
- `data-cy="save-strategy-btn"` - przycisk zapisywania strategii
- `data-cy="regenerate-strategy-btn"` - przycisk regeneracji
- `data-cy="template-*"` - przyciski template'ów strategii

**Symulacje:**
- `data-cy="strategy-select"` - wybór strategii
- `data-cy="target-draw-select"` - wybór losowania docelowego
- `data-cy="start-simulation-btn"` - przycisk uruchomienia symulacji

## 📋 Scenariusze Testowe

### 1. **Rejestracja i Logowanie** (`auth.cy.js`)

#### Scenariusz 1.1: Rejestracja nowego użytkownika
```javascript
describe('User Registration', () => {
  beforeEach(() => {
    cy.task('db:reset') // Wyczyść bazę testową
    cy.visit('/')
    // Czekaj na załadowanie LiveView
    cy.window().its('liveSocket').should('exist')
  })

  it('should register new user successfully', () => {
    // Otwórz modal rejestracji
    cy.get('[data-cy="register-button"]').click()

    // Sprawdź czy modal się otworzył
    cy.get('[data-cy="register-modal"]').should('be.visible')
    cy.get('.modal.modal-open').should('exist')

    // Wypełnij formularz rejestracji
    cy.get('[data-cy="register-form"]').within(() => {
      // Phoenix LiveView używa Phoenix.Component.form/1, więc struktura HTML jest inna
      cy.get('input[name="user[email]"]').type('test@example.com')
      cy.get('input[name="user[password]"]').type('password123')
      cy.get('input[name="user[password_confirmation]"]').type('password123')
      cy.get('[data-cy="register-submit"]').click()
    })

    // Sprawdź przekierowanie na dashboard
    cy.url().should('eq', 'http://localhost:4000/')
    cy.get('[data-cy="user-menu"]').should('contain', 'test@example.com')
    cy.get('h1').should('contain', 'Dashboard')
  })
})
```

#### Scenariusz 1.2: Logowanie istniejącego użytkownika
- Weryfikacja poprawnego logowania
- Obsługa błędnych danych logowania
- Weryfikacja sesji po odświeżeniu strony

#### Scenariusz 1.3: Wylogowanie
- Wylogowanie z aplikacji
- Przekierowanie na stronę główną
- Unieważnienie sesji

### 2. **Zarządzanie Strategiami** (`strategies.cy.js`)

#### Scenariusz 2.1: Tworzenie strategii AI
```javascript
describe('AI Strategy Creation', () => {
  beforeEach(() => {
    cy.login('test@example.com', 'password123')
    // Phoenix LiveView - nawigacja przez przyciski, nie URL
    cy.visit('/')
    cy.get('[data-cy="nav-strategies"]').click()
    cy.get('h1').should('contain', 'Moje Strategie')
  })

  it('should create AI strategy from prompt', () => {
    // Otwórz modal tworzenia strategii
    cy.get('[data-cy="create-strategy-btn"]').click()

    // Sprawdź czy modal się otworzył (DaisyUI modal)
    cy.get('[data-cy="strategy-form-modal"]').should('be.visible')
    cy.get('.modal.modal-open').should('exist')

    // Zakładka AI powinna być domyślnie aktywna
    cy.get('[data-cy="ai-tab"]').should('have.class', 'tab-active')

    // Użyj template'u strategii (szybciej niż ręczne pisanie)
    cy.get('[data-cy="template-tylko-nieparzyste"]').click()

    // Sprawdź czy prompt został wstawiony do textarea
    cy.get('[data-cy="ai-prompt-input"]').should('contain', 'Tylko Nieparzyste')

    // Wygeneruj strategię przez AI
    cy.get('[data-cy="generate-strategy-btn"]').click()

    // Weryfikacja podglądu strategii (może zająć chwilę dla AI)
    cy.get('[data-cy="strategy-preview"]', { timeout: 30000 }).should('be.visible')
    cy.get('[data-cy="strategy-name"]').should('contain', 'Strategia')

    // Zapisanie strategii
    cy.get('[data-cy="save-strategy-btn"]').click()

    // Sprawdź czy strategia została dodana do listy
    cy.get('.card').should('contain', 'Strategia')
  })
})
```

#### Scenariusz 2.2: Tworzenie strategii manualnej
- Formularz tworzenia strategii
- Walidacja parametrów (ratios, weights)
- Zapisywanie i wyświetlanie strategii

#### Scenariusz 2.3: Edycja strategii
- Modyfikacja istniejących strategii
- Walidacja zmian
- Aktualizacja w liście strategii

#### Scenariusz 2.4: Usuwanie strategii
- Potwierdzenie usunięcia
- Aktualizacja UI po usunięciu
- Sprawdzanie powiązań z symulacjami

### 3. **Symulacje** (`simulations.cy.js`)

#### Scenariusz 3.1: Uruchamianie nowej symulacji
```javascript
describe('Simulation Execution', () => {
  beforeEach(() => {
    cy.login('test@example.com', 'password123')
    // Najpierw utwórz strategię przez helper
    cy.createAIStrategy('Test Strategy') // Helper do tworzenia strategii AI
    // Phoenix LiveView - nawigacja przez przyciski
    cy.visit('/')
    cy.get('[data-cy="nav-simulations"]').click()
    cy.get('h1').should('contain', 'Symulacje')
  })

  it('should run simulation successfully', () => {
    // Wybór strategii z dropdown
    cy.get('[data-cy="strategy-select"]').select(1) // Pierwszy element

    // Wybór losowania docelowego
    cy.get('[data-cy="target-draw-select"]').select(1) // Pierwsze losowanie

    // Uruchomienie symulacji
    cy.get('[data-cy="start-simulation-btn"]').click()

    // Sprawdź czy symulacja została dodana do tabeli
    cy.get('.table').should('contain', 'Strategia')

    // Weryfikacja statusu "running" - może być trudne do złapania
    // ponieważ LiveView aktualizuje się natychmiast

    // Weryfikacja real-time updates (jeśli symulacja jest krótka)
    // Dla długich symulacji możemy sprawdzać czy licznik prób rośnie
    cy.get('.table', { timeout: 10000 }).within(() => {
      // Sprawdź czy status się zmienił z "Uruchamiana"
      cy.get('td').should('not.contain', 'Uruchamiana').and('contain', 'Zakończona')
    })
  })
})
```

#### Scenariusz 3.2: Śledzenie postępów w czasie rzeczywistym
- Monitorowanie licznika prób
- Aktualizacja czasu trwania
- Status symulacji

#### Scenariusz 3.3: Ponawianie symulacji zakończonych błędem
- Symulacje z timeout
- Symulacje z przekroczonym limitem prób
- Modyfikacja parametrów i ponowne uruchomienie

#### Scenariusz 3.4: Zarządzanie ulubionymi symulacjami
- Oznaczanie/odznaczanie jako ulubione
- Filtrowanie listy symulacji

### 4. **Rankingi i Analizy** (`ranking.cy.js`)

#### Scenariusz 4.1: Wyświetlanie rankingu strategii
```javascript
describe('Strategy Ranking', () => {
  beforeEach(() => {
    cy.login('test@example.com', 'password123')
    cy.createMultipleStrategies(5) // Helper do tworzenia wielu strategii
    cy.runSimulationsForAllStrategies() // Helper do uruchomienia symulacji
    cy.visit('/ranking')
  })

  it('should display strategies ranked by performance', () => {
    cy.get('[data-cy="ranking-table"]').within(() => {
      cy.get('tbody tr').first().should('contain', 'Najlepsza strategia')
      cy.get('tbody tr').last().should('contain', 'Najgorsza strategia')

      // Weryfikacja kolumn
      cy.get('th').should('contain', 'Strategia')
      cy.get('th').should('contain', 'Średnie próby')
      cy.get('th').should('contain', 'Liczba symulacji')
    })
  })
})
```

#### Scenariusz 4.2: Filtrowanie i sortowanie
- Sortowanie po różnych kryteriach
- Filtrowanie po typie strategii (manualne/AI)
- Filtrowanie po zakresie dat

### 5. **Generator Kuponów** (`generator.cy.js`)

#### Scenariusz 5.1: Generowanie kuponów z najlepszymi strategiami
```javascript
describe('Coupon Generator', () => {
  beforeEach(() => {
    cy.login('test@example.com', 'password123')
    cy.createTopPerformingStrategies() // Helper
    cy.visit('/generator')
  })

  it('should generate coupons from top strategies', () => {
    cy.get('[data-cy="strategy-select"]').select('Najlepsza strategia')
    cy.get('[data-cy="coupon-count-input"]').type('3')
    cy.get('[data-cy="generate-btn"]').click()

    // Weryfikacja wygenerowanych kuponów
    cy.get('[data-cy="generated-coupons"]').within(() => {
      cy.get('[data-cy="coupon"]').should('have.length', 3)

      // Każdy kupon powinien mieć 5 liczb głównych + 2 euro
      cy.get('[data-cy="coupon"]').each(($coupon) => {
        cy.wrap($coupon).find('[data-cy="main-numbers"]').children().should('have.length', 5)
        cy.wrap($coupon).find('[data-cy="euro-numbers"]').children().should('have.length', 2)
      })
    })
  })
})
```

#### Scenariusz 5.2: Regeneracja kuponów
- Ponowne generowanie z tymi samymi parametrami
- Zachowanie różnych wyników

### 6. **API Endpoints** (`api.cy.js`)

#### Scenariusz 6.1: Publiczne API (bez autoryzacji)
```javascript
describe('Public API', () => {
  it('should return latest draws', () => {
    cy.request('GET', '/api/draws/latest').then((response) => {
      expect(response.status).to.eq(200)
      expect(response.body).to.have.property('data')
      expect(response.body.data).to.have.property('numbers')
    })
  })

  it('should return draw analysis', () => {
    cy.request('GET', '/api/draws/analysis').then((response) => {
      expect(response.status).to.eq(200)
      expect(response.body).to.have.property('hot_numbers')
      expect(response.body).to.have.property('cold_numbers')
    })
  })
})
```

#### Scenariusz 6.2: Chronione API (z autoryzacją)
```javascript
describe('Authenticated API', () => {
  let authToken

  before(() => {
    cy.request('POST', '/api/auth/token', {
      email: 'test@example.com',
      password: 'password123'
    }).then((response) => {
      authToken = response.body.token
    })
  })

  it('should create strategy via API', () => {
    cy.request({
      method: 'POST',
      url: '/api/strategies',
      headers: { 'Authorization': `Bearer ${authToken}` },
      body: {
        name: 'API Strategy',
        rules: { /* strategy rules */ }
      }
    }).then((response) => {
      expect(response.status).to.eq(201)
      expect(response.body).to.have.property('id')
    })
  })
})
```

### 7. **Dashboard i Nawigacja** (`dashboard.cy.js`)

#### Scenariusz 7.1: Dashboard użytkownika
- Wyświetlanie statystyk użytkownika
- Lista ostatnich symulacji
- Szybkie akcje

#### Scenariusz 7.2: Nawigacja między sekcjami
- Przejścia między zakładkami
- Zachowanie stanu podczas nawigacji
- Responsywność UI

## 🔧 Specyfika Testowania Phoenix LiveView

### Kluczowe Różnice vs Tradycyjne SPA

**1. Brak URL Routing dla Sekcji:**
```javascript
// ❌ NIEPOPRAWNE - nie ma takich URL
cy.visit('/strategies')
cy.visit('/simulations')

// ✅ POPRAWNE - nawigacja przez przyciski LiveView
cy.visit('/')
cy.get('[data-cy="nav-strategies"]').click()
cy.get('h1').should('contain', 'Moje Strategie')
```

**2. Czekanie na LiveView Mount:**
```javascript
beforeEach(() => {
  cy.visit('/')
  // Zawsze czekaj na załadowanie LiveView
  cy.window().its('liveSocket').should('exist')
})
```

**3. Modals w DaisyUI:**
```javascript
// Sprawdź czy modal jest widoczny
cy.get('[data-cy="register-modal"]').should('be.visible')
cy.get('.modal.modal-open').should('exist')

// Zamknij modal
cy.get('[data-cy="register-cancel"]').click()
cy.get('[data-cy="register-modal"]').should('not.be.visible')
```

**4. Real-time Updates:**
```javascript
// Czekaj na aktualizacje LiveView (mogą trwać dłużej)
cy.get('[data-cy="simulation-status"]', { timeout: 30000 })
  .should('contain', 'Zakończona')

// Sprawdź czy licznik prób się aktualizuje
cy.get('[data-cy="simulation-attempts"]').then(($attempts) => {
  const initialCount = parseInt($attempts.text())
  cy.wait(2000) // Czekaj na update
  cy.get('[data-cy="simulation-attempts"]').should(($newAttempts) => {
    expect(parseInt($newAttempts.text())).to.be.greaterThan(initialCount)
  })
})
```

**5. Phoenix Forms Structure:**
```javascript
// Phoenix.Component.form/1 generuje inną strukturę HTML
cy.get('[data-cy="register-form"]').within(() => {
  // Nazwy inputów są takie same, ale struktura może się różnić
  cy.get('input[name="user[email]"]').type('test@example.com')
  cy.get('input[name="user[password]"]').type('password123')
})
```

### Problemy z Timing

**Race Conditions:**
- LiveView aktualizuje się asynchronicznie
- AI requests mogą trwać 10-30 sekund
- Symulacje mogą trwać od sekund do minut

**Rozwiązania:**
```javascript
// Zwiększ timeout dla długich operacji
cy.get('[data-cy="ai-result"]', { timeout: 30000 }).should('be.visible')

// Użyj retry-ability Cypress
cy.get('.table').should('contain', 'Strategia').and('contain', 'Zakończona')

// Sprawdź czy element zniknął
cy.get('[data-cy="loading-spinner"]').should('not.exist')
```

## 🔧 Helper Functions

### Database Helpers (`cypress/support/db-helpers.js`)
```javascript
Cypress.Commands.add('dbReset', () => {
  cy.task('db:reset')
})

Cypress.Commands.add('dbSeed', () => {
  cy.task('db:seed')
})

Cypress.Commands.add('dbCreateUser', (email, password) => {
  cy.task('db:createUser', { email, password })
})

Cypress.Commands.add('dbCreateStrategy', (userId, strategyData) => {
  cy.task('db:createStrategy', { userId, strategyData })
})
```

### UI Helpers (`cypress/support/ui-helpers.js`)
```javascript
Cypress.Commands.add('login', (email, password) => {
  cy.session([email, password], () => {
    cy.visit('/')
    cy.window().its('liveSocket').should('exist')

    // Otwórz modal logowania
    cy.get('[data-cy="login-button"]').click()
    cy.get('[data-cy="login-modal"]').should('be.visible')

    // Wypełnij formularz
    cy.get('[data-cy="login-form"]').within(() => {
      cy.get('input[name="user[email]"]').type(email)
      cy.get('input[name="user[password]"]').type(password)
      cy.get('[data-cy="login-submit"]').click()
    })

    // Sprawdź przekierowanie na dashboard
    cy.url().should('eq', 'http://localhost:4000/')
    cy.get('[data-cy="user-menu"]').should('contain', email)
  })
})

Cypress.Commands.add('createAIStrategy', (strategyName = 'Test Strategy') => {
  // Przejdź do strategii
  cy.visit('/')
  cy.get('[data-cy="nav-strategies"]').click()

  // Otwórz modal tworzenia strategii
  cy.get('[data-cy="create-strategy-btn"]').click()
  cy.get('[data-cy="strategy-form-modal"]').should('be.visible')

  // Użyj template'u (szybciej niż ręczne pisanie)
  cy.get('[data-cy="template-balans-hot-cold"]').click()

  // Wygeneruj strategię przez AI
  cy.get('[data-cy="generate-strategy-btn"]').click()

  // Czekaj na podgląd strategii
  cy.get('[data-cy="strategy-preview"]', { timeout: 30000 }).should('be.visible')

  // Zapisz strategię
  cy.get('[data-cy="save-strategy-btn"]').click()

  // Sprawdź czy strategia została utworzona
  cy.get('.card').should('contain', 'Strategia')
})

Cypress.Commands.add('runSimulation', (strategyIndex = 0, targetDrawIndex = 0) => {
  // Przejdź do symulacji
  cy.visit('/')
  cy.get('[data-cy="nav-simulations"]').click()

  // Wybierz strategię i losowanie
  cy.get('[data-cy="strategy-select"]').select(strategyIndex)
  cy.get('[data-cy="target-draw-select"]').select(targetDrawIndex)

  // Uruchom symulację
  cy.get('[data-cy="start-simulation-btn"]').click()

  // Sprawdź czy symulacja została dodana
  cy.get('.table').should('contain', 'Strategia')
})

Cypress.Commands.add('waitForSimulationComplete', (timeoutMs = 60000) => {
  cy.get('.table', { timeout: timeoutMs }).within(() => {
    // Sprawdź czy status zmienił się na zakończony
    cy.get('td').should('contain', 'Zakończona')
  })
})
```

## 📊 Raportowanie i CI/CD

### Konfiguracja CI
```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on: [push, pull_request]
jobs:
  e2e:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_DB: numbers_evolution_test_e2e
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - uses: erlef/setup-beam@v1
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.14'
          otp-version: '25'
      - name: Install dependencies
        run: |
          mix deps.get
          npm install
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
      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: cypress-results
          path: cypress/videos/
```

### Raporty Testowe
- **Videos**: Nagrywanie wszystkich testów
- **Screenshots**: Zrzuty ekranu przy błędach
- **Test Results**: Szczegółowe logi wykonania
- **Coverage**: Raport pokrycia kodu (jeśli skonfigurowane)

## 🚀 Strategia Wykonania

### Faza 0: Przygotowanie Aplikacji ✅ (Wykonane)
- [x] **Dodanie atrybutów `data-cy`** do kluczowych elementów UI
- [x] Skonfiguruj `MIX_ENV=test_e2e` w `config/test_e2e.exs`
- [x] Stwórz helper do seedowania danych testowych

### Faza 1: Podstawowa Infrastruktura ✅ (Wykonane)
- [x] Konfiguracja bazy PostgreSQL `numbers_evolution_test_e2e`
- [x] Konfiguracja Cypress z dedykowaną bazą testową
- [x] Implementacja database helpers (`cy.task('db:reset')`)
- [x] Implementacja UI helpers (login, createAIStrategy, runSimulation)
- [x] Mix task do zarządzania bazą E2E (`mix e2e_db`)
- [x] CI/CD pipeline configuration

### Faza 2: Core Features - Auth ✅ (Wykonane)
- [x] Testy rejestracji nowego użytkownika
- [x] Testy logowania istniejącego użytkownika
- [x] Testy wylogowania
- [x] Testy błędnych danych logowania
- [x] Testy walidacji formularzy
- [x] Testy session persistence

### Faza 3: Core Features - Strategie ✅ (Wykonane)
- [x] Testy tworzenia strategii AI (z template'ami)
- [x] Testy generowania strategii przez AI
- [x] Testy zapisywania strategii
- [x] Testy wyświetlania strategii w liście
- [x] Testy usuwania strategii
- [x] Testy template'ów strategii

### Faza 4: Core Features - Symulacje ✅ (Wykonane)
- [x] Testy uruchamiania symulacji
- [x] Testy śledzenia postępów (live updates)
- [x] Testy zakończonych symulacji
- [x] Testy historii symulacji
- [x] Testy akcji (retry, delete, favorite)
- [x] Testy zaawansowanych opcji

### Faza 5: Dashboard i Nawigacja ⚠️ (Podstawowe)
- [x] Testy nawigacji między sekcjami (basic)
- [ ] Testy dashboard z statystykami (częściowo pokryte w auth testach)
- [x] Testy szybkich akcji (basic)
- [ ] Testy responsywności UI

### Faza 6: Advanced Features ❌ (Nie zaimplementowane)
- [ ] Testy rankingu strategii
- [ ] Testy generatora kuponów
- [ ] Testy API endpoints (publiczne)
- [ ] Testy błędów i edge cases

### Faza 7: Optymalizacja i CI/CD (ciągłe)
- [x] Dokumentacja README dla testów E2E
- [ ] Optymalizacja czasu wykonania testów
- [ ] Parallel execution setup
- [ ] Video recordings i screenshots
- [ ] Dodawanie nowych testów przy rozwoju funkcji

## 📈 Metryki Sukcesu

- **Coverage**: >90% kluczowych ścieżek użytkownika
- **Reliability**: >95% testów przechodzi
- **Performance**: <5 min całkowitego czasu wykonania
- **Maintenance**: <30 min na dodanie nowego testu

## 🔍 Najlepsze Praktyki

1. **Page Object Pattern**: Używanie selektorów `data-cy` dla stabilności
2. **Test Isolation**: Każdy test niezależny, czyszczenie stanu
3. **Realistic Data**: Używanie prawdziwych danych testowych
4. **Flaky Test Prevention**: Unikanie race conditions i timing issues
5. **Cross-browser Testing**: Testy na Chrome, Firefox, Safari

## 🐛 Obsługa Błędów i Debugowanie

### Częste Problemy
- **Race Conditions**: Używanie `cy.wait()` lub `cy.intercept()` dla API calls
- **LiveView Updates**: Czekanie na aktualizacje Phoenix LiveView
- **Database State**: Zapewnienie czystości danych między testami

### Debugowanie
```javascript
// Dodanie logów dla debugowania
cy.window().then((win) => {
  cy.spy(win.console, 'log')
})

// Wizualne pauzy dla manualnego debugowania
cy.pause()

// Screenshot przy błędach
Cypress.on('fail', (error, runnable) => {
  cy.screenshot(`error-${runnable.title}`)
})
```

---

**Data utworzenia**: 21 listopada 2025
**Data ostatniej aktualizacji**: 21 listopada 2025
**Wersja**: 2.0
**Autor**: AI Assistant
**Status**: ✅ **ZAIMPLEMENTOWANE I GOTOWE DO URUCHOMIENIA**

## 📊 Podsumowanie Implementacji

| Komponent | Status | Opis |
|-----------|--------|------|
| **Data-cy Attributes** | ✅ | Dodane do wszystkich kluczowych elementów UI |
| **Konfiguracja Cypress** | ✅ | Pełna konfiguracja z dedykowaną bazą |
| **Mix Tasks** | ✅ | `mix e2e_db` do zarządzania bazą testową |
| **Custom Commands** | ✅ | login, createAIStrategy, runSimulation |
| **Testy Auth** | ✅ | Rejestracja, logowanie, wylogowanie, walidacja |
| **Testy Strategii** | ✅ | AI generation, templates, CRUD |
| **Testy Symulacji** | ✅ | Uruchamianie, live tracking, historia |
| **Dokumentacja** | ✅ | README, troubleshooting, best practices |
| **CI/CD Ready** | ✅ | GitHub Actions configuration |

## 🚀 Jak uruchomić

```bash
# 1. Przygotuj środowisko
npm install

# 2. Uruchom Phoenix w trybie E2E
MIX_ENV=test_e2e mix phx.server

# 3. W osobnym terminalu uruchom testy
npm run cypress:run
```

**Test User:** `test@example.com` / `testpassword123`
