import { defineConfig } from 'cypress'

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
    },
    setupNodeEvents(on, config) {
      // Database tasks for E2E testing
      on('task', {
        'db:reset': async () => {
          // Use API endpoint to reset database instead of direct mix task
          try {
            const response = await fetch(`${config.env.API_BASE_URL}/e2e/reset-db`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json'
              }
            })

            if (!response.ok) {
              const body = await response.text()
              throw new Error(`Database reset failed: ${body}`)
            }

            return null
          } catch (error) {
            throw new Error(`Database reset failed: ${error.message}`)
          }
        },
        'db:seed': () => {
          // For now, just return success - seeding is done during reset
          return true
        },
        'db:createUser': ({ email, password }) => {
          // For now, just return success - test user is created during db:reset
          return true
        },
        'db:createStrategy': ({ userId, strategyData }) => {
          // For now, just return success - strategies are created through UI in tests
          return true
        }
      })
    },
  },
})
