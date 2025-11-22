describe.skip('Strategies Management', () => {
  beforeEach(() => {
    // Clear all browser state to ensure clean test environment
    cy.clearCookies()
    cy.clearLocalStorage()
    cy.window().then(win => {
      win.sessionStorage.clear()
    })

    // Reset database
    cy.task('db:reset')

    // Manual login without session caching
    cy.visit('/')
    cy.get('[data-cy="login-button"]').click()
    cy.get('[data-cy="login-modal"]', { timeout: 10000 }).should('be.visible')
    cy.get('[data-cy="login-form"]').within(() => {
      cy.get('input[name="user[email]"]').type('test@example.com')
      cy.get('input[name="user[password]"]').type('testpassword123')
      cy.get('[data-cy="login-submit"]').click()
    })
    cy.url().should('satisfy', (url) => {
      const normalized = url.replace('localhost', '127.0.0.1')
      return normalized === 'http://127.0.0.1:4000/' || normalized === 'http://127.0.0.1:4000'
    })

    // Navigate to strategies section
    cy.get('[data-cy="nav-strategies"]').click()
    cy.get('h1').should('contain', 'Moje Strategie')
  })

  describe('Empty State', () => {
    it('should show empty state when no strategies exist', () => {
      cy.get('.empty-state').should('be.visible')
      cy.get('.empty-state').should('contain', 'Nie masz jeszcze strategii')
      cy.get('[data-cy="create-strategy-btn"]').should('be.visible')
    })
  })

  describe('AI Strategy Creation', () => {
    it('should create AI strategy using template', () => {
      // Open strategy creation modal
      cy.get('[data-cy="create-strategy-btn"]').click()

      // Verify modal is open
      cy.get('[data-cy="strategy-form-modal"]').should('be.visible')
      cy.get('.modal.modal-open').should('exist')

      // AI tab should be active by default
      cy.get('[data-cy="ai-tab"]').should('have.class', 'tab-active')

      // Use a strategy template
      cy.get('[data-cy="template-balans-hot-cold"]').click()

      // Verify prompt was filled
      cy.get('textarea[name="prompt"]').should('contain', 'Balans Hot/Cold')

      // Generate strategy (this may take time due to AI)
      cy.get('[data-cy="generate-strategy-btn"]').click()

      // Wait for strategy preview (may take up to 30 seconds)
      cy.get('[data-cy="strategy-preview"]', { timeout: 30000 }).should('be.visible')
      cy.get('[data-cy="strategy-name"]').should('contain', 'Strategia')

      // Save the strategy
      cy.get('[data-cy="save-strategy-btn"]').click()

      // Verify strategy was created and appears in list
      cy.get('.card').should('contain', 'Strategia')
      cy.get('.card').should('contain', 'AI')
    })

    it('should regenerate strategy preview', () => {
      // Create initial strategy
      cy.get('[data-cy="create-strategy-btn"]').click()
      cy.get('[data-cy="template-ekstremalna-hot"]').click()
      cy.get('[data-cy="generate-strategy-btn"]').click()
      cy.get('[data-cy="strategy-preview"]', { timeout: 30000 }).should('be.visible')

      // Regenerate strategy
      cy.get('[data-cy="regenerate-strategy-btn"]').click()

      // Preview should still be visible (regenerate doesn't close it)
      cy.get('[data-cy="strategy-preview"]', { timeout: 30000 }).should('be.visible')
    })

    it('should cancel strategy creation', () => {
      // Open modal
      cy.get('[data-cy="create-strategy-btn"]').click()
      cy.get('[data-cy="strategy-form-modal"]').should('be.visible')

      // Close modal
      cy.get('button').contains('Zamknij').click()

      // Modal should be closed
      cy.get('[data-cy="strategy-form-modal"]').should('not.be.visible')
      cy.get('.modal.modal-open').should('not.exist')
    })
  })

  describe('Strategy Templates', () => {
    it('should fill prompt when template is selected', () => {
      cy.get('[data-cy="create-strategy-btn"]').click()

      // Test different templates
      cy.get('[data-cy="template-tylko-nieparzyste"]').click()
      cy.get('textarea[name="prompt"]').should('contain', 'Tylko Nieparzyste')

      cy.get('[data-cy="template-dwie-nieparzyste-trzy-parzyste"]').click()
      cy.get('textarea[name="prompt"]').should('contain', '2 Nieparzyste, 3 Parzyste')
    })
  })

  describe('Strategy Display', () => {
    beforeEach(() => {
      // Create a strategy for testing display
      cy.createAIStrategy('Display Test Strategy')
      cy.visit('/')
      cy.get('[data-cy="nav-strategies"]').click()
    })

    it('should display strategy with correct information', () => {
      cy.get('.card').within(() => {
        cy.get('.card-title').should('contain', 'Strategia')
        cy.get('.badge').should('contain', 'AI')
        cy.get('button').should('contain', 'Szczegóły')
        cy.get('button').should('contain', 'Usuń')
      })
    })

    it('should show strategy statistics', () => {
      cy.get('.card').within(() => {
        cy.get('.stat-title').should('contain', 'Performance')
        cy.get('.stat-value').should('exist')
      })
    })
  })

  describe('Strategy Deletion', () => {
    beforeEach(() => {
      cy.createAIStrategy('Delete Test Strategy')
      cy.visit('/')
      cy.get('[data-cy="nav-strategies"]').click()
    })

    it('should delete strategy with confirmation', () => {
      // Strategy should exist
      cy.get('.card').should('contain', 'Strategia')

      // Click delete button (may require confirmation)
      cy.get('button').contains('Usuń').click()

      // Strategy should be removed
      cy.get('.card').should('not.contain', 'Strategia')
    })
  })

  describe('Navigation', () => {
    it('should navigate to strategies from dashboard', () => {
      // Go to dashboard
      cy.visit('/')
      cy.get('[data-cy="nav-dashboard"]').click()
      cy.get('h1').should('contain', 'Dashboard')

      // Navigate to strategies
      cy.get('[data-cy="quick-create-strategy"]').click()
      cy.get('h1').should('contain', 'Moje Strategie')
    })
  })
})
