describe('Authentication', () => {
  beforeEach(() => {
    // Reset database before each test
    cy.task('db:reset')
    cy.visit('/')
    cy.window().its('liveSocket').should('exist')
  })

  describe('User Registration', () => {
    it('should register new user successfully', () => {
      // Open registration modal
      cy.get('[data-cy="register-button"]').click()

      // Verify modal is visible
      cy.get('[data-cy="register-modal"]').should('be.visible')
      cy.get('.modal.modal-open').should('exist')

      // Fill registration form
      cy.get('[data-cy="register-form"]').within(() => {
        cy.get('input[name="user[email]"]').type('newuser@example.com')
        cy.get('input[name="user[password]"]').type('password123')
        cy.get('input[name="user[password_confirmation]"]').type('password123')
        cy.get('[data-cy="register-submit"]').click()
      })

      // Verify redirect to dashboard
      cy.url().should('eq', 'http://127.0.0.1:4000/')
      cy.get('[data-cy="user-menu"]').should('contain', 'newuser@example.com')
      cy.get('h1').should('contain', 'Dashboard')
    })

    it('should show validation errors for invalid registration', () => {
      // Open registration modal
      cy.get('[data-cy="register-button"]').click()
      cy.get('[data-cy="register-modal"]').should('be.visible')

      // Try to register with invalid data
      cy.get('[data-cy="register-form"]').within(() => {
        cy.get('input[name="user[email]"]').type('invalid-email')
        cy.get('input[name="user[password]"]').type('123')
        cy.get('input[name="user[password_confirmation]"]').type('456')
        cy.get('[data-cy="register-submit"]').click()
      })

      // Modal should still be open with validation errors
      cy.get('[data-cy="register-modal"]').should('be.visible')
      cy.get('.modal.modal-open').should('exist')
    })

    it('should cancel registration', () => {
      // Open registration modal
      cy.get('[data-cy="register-button"]').click()
      cy.get('[data-cy="register-modal"]').should('be.visible')

      // Cancel registration
      cy.get('[data-cy="register-cancel"]').click()

      // Modal should be closed
      cy.get('[data-cy="register-modal"]').should('not.be.visible')
      cy.get('.modal.modal-open').should('not.exist')
    })
  })

  describe('User Login', () => {
    it('should login existing user successfully', () => {
      // Open login modal
      cy.get('[data-cy="login-button"]').click()

      // Verify modal is visible
      cy.get('[data-cy="login-modal"]').should('be.visible')
      cy.get('.modal.modal-open').should('exist')

      // Fill login form with test user credentials
      cy.get('[data-cy="login-form"]').within(() => {
        cy.get('input[name="user[email]"]').type('test@example.com')
        cy.get('input[name="user[password]"]').type('testpassword123')
        cy.get('[data-cy="login-submit"]').click()
      })

      // Verify redirect to dashboard
      cy.url().should('eq', 'http://127.0.0.1:4000/')
      cy.get('[data-cy="user-menu"]').should('contain', 'test@example.com')
      cy.get('h1').should('contain', 'Dashboard')
    })

    it('should show error for invalid credentials', () => {
      // Open login modal
      cy.get('[data-cy="login-button"]').click()
      cy.get('[data-cy="login-modal"]').should('be.visible')

      // Try to login with wrong credentials
      cy.get('[data-cy="login-form"]').within(() => {
        cy.get('input[name="user[email]"]').type('test@example.com')
        cy.get('input[name="user[password]"]').type('wrongpassword')
        cy.get('[data-cy="login-submit"]').click()
      })

      // Modal should still be open
      cy.get('[data-cy="login-modal"]').should('be.visible')
      cy.get('.modal.modal-open').should('exist')
    })

    it('should cancel login', () => {
      // Open login modal
      cy.get('[data-cy="login-button"]').click()
      cy.get('[data-cy="login-modal"]').should('be.visible')

      // Cancel login
      cy.get('[data-cy="login-cancel"]').click()

      // Modal should be closed
      cy.get('[data-cy="login-modal"]').should('not.be.visible')
      cy.get('.modal.modal-open').should('not.exist')
    })
  })

  describe('User Logout', () => {
    beforeEach(() => {
      // Login first
      cy.login('test@example.com', 'testpassword123')
    })

    it('should logout user successfully', () => {
      // Verify user is logged in
      cy.get('[data-cy="user-menu"]').should('contain', 'test@example.com')

      // Open user menu and click logout
      cy.get('[data-cy="user-menu"]').click()
      cy.get('[data-cy="logout-button"]').click()

      // Should redirect to landing page
      cy.url().should('eq', 'http://127.0.0.1:4000/')
      cy.get('[data-cy="register-button"]').should('be.visible')
      cy.get('[data-cy="login-button"]').should('be.visible')
      cy.get('[data-cy="user-menu"]').should('not.exist')
    })
  })

  describe('Session Persistence', () => {
    it('should maintain session after page refresh', () => {
      // Login
      cy.login('test@example.com', 'testpassword123')

      // Refresh page
      cy.reload()

      // Should still be logged in
      cy.get('[data-cy="user-menu"]').should('contain', 'test@example.com')
      cy.get('h1').should('contain', 'Dashboard')
    })
  })
})
