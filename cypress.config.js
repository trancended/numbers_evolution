import { defineConfig } from 'cypress'
import http from 'http'

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
          // Use API endpoint to reset database with retry logic
          const maxRetries = 3
          const retryDelay = 2000
          
          for (let attempt = 1; attempt <= maxRetries; attempt++) {
            try {
              const result = await new Promise((resolve, reject) => {
                const url = `${config.env.API_BASE_URL}/e2e/reset-db`
                const parsedUrl = new URL(url)
                
                const options = {
                  hostname: parsedUrl.hostname,
                  port: parsedUrl.port || 4000,
                  path: parsedUrl.pathname,
                  method: 'POST',
                  headers: {
                    'Content-Type': 'application/json'
                  },
                  timeout: 10000
                }

                console.log(`[db:reset] Attempt ${attempt}/${maxRetries} - Calling ${url}`)

                const req = http.request(options, (res) => {
                  let data = ''
                  
                  res.on('data', (chunk) => {
                    data += chunk
                  })
                  
                  res.on('end', () => {
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                      console.log('[db:reset] Success:', data)
                      resolve(null)
                    } else {
                      reject(new Error(`HTTP ${res.statusCode}: ${data}`))
                    }
                  })
                })

                req.on('error', (error) => {
                  reject(error)
                })

                req.on('timeout', () => {
                  req.destroy()
                  reject(new Error('Request timeout'))
                })

                req.end()
              })
              
              return result
            } catch (error) {
              console.error(`[db:reset] Attempt ${attempt} failed:`, error.message)
              
              if (attempt === maxRetries) {
                throw new Error(`Database reset failed after ${maxRetries} attempts: ${error.message}`)
              }
              
              // Wait before retry
              await new Promise(resolve => setTimeout(resolve, retryDelay))
            }
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
