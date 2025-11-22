// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************
//
//
// -- This is a parent command --
// Cypress.Commands.add('login', (email, password) => { ... })
//
//
// -- This is a child command --
// Cypress.Commands.add('drag', { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add('dismiss', { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This will overwrite an existing command --
// Cypress.Commands.overwrite('visit', (originalFn, url, options) => { ... })
//
// declare global {
//   namespace Cypress {
//     interface Chainable {
//       login(email: string, password: string): Chainable<void>
//       drag(subject: string, options?: Partial<TypeOptions>): Chainable<Element>
//       dismiss(subject: string, options?: Partial<TypeOptions>): Chainable<Element>
//       visit(originalFn: CommandOriginalFn, url: string, options: Partial<VisitOptions>): Chainable<Element>
//     }
//   }
// }

Cypress.Commands.add('login', (email, password) => {
  cy.session([email, password], () => {
    // Wyczyść wszystkie cookies i localStorage przed logowaniem
    cy.clearCookies()
    cy.clearLocalStorage()

    cy.visit('/')
    cy.window().its('liveSocket').should('exist')

    // Sprawdź czy jesteśmy na stronie landing (niezalogowani)
    cy.get('[data-cy="login-button"]').should('be.visible')

    // Otwórz modal logowania
    cy.get('[data-cy="login-button"]').click()
    // Wait for LiveView to process the event and render the modal
    cy.get('[data-cy="login-modal"]', { timeout: 5000 }).should('be.visible')

    // Wypełnij formularz
    cy.get('[data-cy="login-form"]').within(() => {
      cy.get('input[name="user[email]"]').type(email)
      cy.get('input[name="user[password]"]').type(password)
      cy.get('[data-cy="login-submit"]').click()
    })

    // Sprawdź przekierowanie na dashboard - normalize URL comparison
    cy.url().should('satisfy', (url) => {
      const normalized = url.replace('localhost', '127.0.0.1')
      return normalized === 'http://127.0.0.1:4000/' || normalized === 'http://127.0.0.1:4000'
    })
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
