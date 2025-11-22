describe('Simulations', () => {
  beforeEach(() => {
    cy.login('test@example.com', 'testpassword123')
    // Create a strategy first
    cy.createAIStrategy('Simulation Test Strategy')
    // Navigate to simulations
    cy.visit('/')
    cy.get('[data-cy="nav-simulations"]').click()
    cy.get('h1').should('contain', 'Symulacje')
  })

  describe('Empty State', () => {
    it('should show empty state when no simulations exist', () => {
      // Clear any existing simulations first
      cy.task('db:reset')
      cy.login('test@example.com', 'testpassword123')
      cy.createAIStrategy('Empty Test Strategy')
      cy.visit('/')
      cy.get('[data-cy="nav-simulations"]').click()

      cy.get('.empty-state').should('be.visible')
      cy.get('.empty-state').should('contain', 'Brak symulacji')
    })
  })

  describe('Simulation Creation', () => {
    it('should start simulation successfully', () => {
      // Strategy and target draw should be selectable
      cy.get('[data-cy="strategy-select"]').should('be.visible')
      cy.get('[data-cy="target-draw-select"]').should('be.visible')

      // Select first available strategy and draw
      cy.get('[data-cy="strategy-select"]').select(0)
      cy.get('[data-cy="target-draw-select"]').select(0)

      // Start simulation
      cy.get('[data-cy="start-simulation-btn"]').click()

      // Simulation should appear in the table
      cy.get('.table').should('contain', 'Strategia')
      cy.get('.table').should('contain', 'Uruchamiana')
    })

    it('should show strategy pools when strategy is selected', () => {
      cy.get('[data-cy="strategy-select"]').select(0)

      // Strategy pools should be displayed
      cy.get('.bg-base-200').should('be.visible')
      cy.get('.bg-base-200').should('contain', 'Hot')
      cy.get('.bg-base-200').should('contain', 'Cold')
      cy.get('.bg-base-200').should('contain', 'Random')
    })

    it('should validate target draw selection', () => {
      cy.get('[data-cy="strategy-select"]').select(0)
      cy.get('[data-cy="target-draw-select"]').select(0)

      // No validation error should be shown initially
      cy.get('.alert-warning').should('not.exist')

      // Start simulation
      cy.get('[data-cy="start-simulation-btn"]').click()
      cy.get('.table').should('contain', 'Strategia')
    })
  })

  describe('Simulation Progress Tracking', () => {
    it('should show simulation status changes', () => {
      // Start simulation
      cy.get('[data-cy="strategy-select"]').select(0)
      cy.get('[data-cy="target-draw-select"]').select(0)
      cy.get('[data-cy="start-simulation-btn"]').click()

      // Initially should show "Uruchamiana"
      cy.get('.table').should('contain', 'Uruchamiana')

      // Wait for simulation to complete (may take time)
      cy.waitForSimulationComplete(120000)

      // Should eventually show "Zakończona"
      cy.get('.table').should('contain', 'Zakończona')
    })

    it('should display attempt counts during simulation', () => {
      // Start simulation
      cy.get('[data-cy="strategy-select"]').select(0)
      cy.get('[data-cy="target-draw-select"]').select(0)
      cy.get('[data-cy="start-simulation-btn"]').click()

      // Wait a bit for simulation to start processing
      cy.wait(5000)

      // Should show attempt count greater than 0
      cy.get('.table').within(() => {
        cy.get('td').should('match', /\d+/) // Should contain numbers
      })
    })
  })

  describe('Simulation History', () => {
    beforeEach(() => {
      // Start a simulation
      cy.get('[data-cy="strategy-select"]').select(0)
      cy.get('[data-cy="target-draw-select"]').select(0)
      cy.get('[data-cy="start-simulation-btn"]').click()

      // Wait for it to complete
      cy.waitForSimulationComplete(120000)
    })

    it('should display completed simulation in history', () => {
      cy.get('.table').within(() => {
        // Should have simulation row
        cy.get('tbody tr').should('have.length.at.least', 1)

        // Should contain strategy name
        cy.get('td').should('contain', 'Strategia')

        // Should show completion status
        cy.get('td').should('contain', 'Zakończona')

        // Should show attempt count
        cy.get('td').should('match', /\d+/)
      })
    })

    it('should show simulation details', () => {
      cy.get('.table').within(() => {
        // Should show strategy pools information
        cy.get('td').should('contain', 'Hot')
        cy.get('td').should('contain', 'Cold')

        // Should show target draw numbers
        cy.get('td').should('match', /\d+/) // Numbers in draw
      })
    })
  })

  describe('Simulation Actions', () => {
    beforeEach(() => {
      // Start a simulation
      cy.get('[data-cy="strategy-select"]').select(0)
      cy.get('[data-cy="target-draw-select"]').select(0)
      cy.get('[data-cy="start-simulation-btn"]').click()
      cy.waitForSimulationComplete(120000)
    })

    it('should allow retrying completed simulation', () => {
      // Should show retry button
      cy.get('button').contains('Ponów').should('be.visible')

      // Click retry
      cy.get('button').contains('Ponów').click()

      // Should show new simulation
      cy.get('.table').should('contain', 'Uruchamiana')
    })

    it('should allow deleting simulation', () => {
      const initialRowCount = cy.get('tbody tr').its('length')

      // Click delete button
      cy.get('button').contains('Usuń').click()

      // Simulation should be removed from table
      cy.get('tbody tr').should('have.length.lessThan', initialRowCount)
    })

    it('should allow toggling favorite status', () => {
      // Initially should show "Oznacz" (not favorite)
      cy.get('button').contains('Oznacz').should('be.visible')

      // Click to favorite
      cy.get('button').contains('Oznacz').click()

      // Should now show "Oznaczona" (favorite)
      cy.get('button').contains('Oznaczona').should('be.visible')
    })
  })

  describe('Advanced Simulation Options', () => {
    it('should show advanced options when expanded', () => {
      // Advanced options should be collapsed by default
      cy.get('details').should('not.have.attr', 'open')

      // Expand advanced options
      cy.get('summary').contains('Opcjonalne limity').click()

      // Should show advanced options
      cy.get('details').should('have.attr', 'open')
      cy.get('input[name="max_attempts"]').should('be.visible')
      cy.get('input[name="timeout_seconds"]').should('be.visible')
    })

    it('should allow custom simulation limits', () => {
      // Expand advanced options
      cy.get('summary').contains('Opcjonalne limity').click()

      // Set custom limits
      cy.get('input[name="max_attempts"]').clear().type('1000')
      cy.get('input[name="timeout_seconds"]').clear().type('300')

      // Select strategy and draw
      cy.get('[data-cy="strategy-select"]').select(0)
      cy.get('[data-cy="target-draw-select"]').select(0)

      // Start simulation
      cy.get('[data-cy="start-simulation-btn"]').click()

      // Should start with custom limits
      cy.get('.table').should('contain', 'Strategia')
    })
  })

  describe('Navigation', () => {
    it('should navigate to simulations from dashboard', () => {
      // Go to dashboard
      cy.visit('/')
      cy.get('[data-cy="nav-dashboard"]').click()

      // Navigate to simulations
      cy.get('[data-cy="quick-run-simulation"]').click()
      cy.get('h1').should('contain', 'Symulacje')
    })
  })
})
