# Cypress E2E Tests

## Prerequisites

Before running E2E tests, ensure you have:

1. PostgreSQL running locally
2. Database `numbers_evolution_e2e` created
3. Phoenix server running in `test_e2e` environment

## Quick Start

### Option 1: Using Helper Script (Easiest)

Use the provided helper script:
```bash
./scripts/e2e.sh
```

This will:
- Check PostgreSQL is running
- Create the database if needed
- Run migrations
- Start the Phoenix server in `test_e2e` environment

Then in a separate terminal, run:
```bash
npm run cypress:run
```

### Option 2: Manual Setup (Recommended for Development)

1. **Setup database:**
   ```bash
   MIX_ENV=test_e2e mix ecto.create
   MIX_ENV=test_e2e mix ecto.migrate
   ```

2. **Start Phoenix server in `test_e2e` environment:**
   ```bash
   MIX_ENV=test_e2e mix phx.server
   ```
   
   Or use the npm script:
   ```bash
   npm run e2e:server
   ```

3. **In a separate terminal, run Cypress tests:**
   ```bash
   npm run cypress:run
   ```
   
   Or open Cypress UI:
   ```bash
   npm run cypress:open
   ```

### Option 2: Automated Setup (All-in-one)

Run everything in one command:
```bash
npm run e2e:test
```

**Note:** This will setup the database, start the server, run tests, and stop the server automatically.

## Environment Variables

The Phoenix server must run with:
- `MIX_ENV=test_e2e` - Required for E2E endpoints to be available
- `DATABASE_URL` - Optional, defaults to `postgresql://postgres:postgres@localhost:5432/numbers_evolution_e2e`
- `SECRET_KEY_BASE` - Optional, uses default from `config/test_e2e.exs`

## Important Notes

⚠️ **The E2E reset endpoint (`/api/e2e/reset-db`) is ONLY available when `MIX_ENV=test_e2e`**

If you see the error:
```
HTTP 403: {"message":"E2E endpoints only available in test_e2e environment"}
```

Make sure you're running the server with `MIX_ENV=test_e2e`.

## Test Structure

- `cypress/e2e/auth.cy.js` - Authentication tests (registration, login, logout)
- `cypress/e2e/strategies.cy.js` - Strategy management tests
- `cypress/e2e/simulations.cy.js` - Simulation tests

## Custom Commands

The following custom Cypress commands are available:

- `cy.login(email, password)` - Login a user (uses session caching)
- `cy.createAIStrategy(name)` - Create an AI strategy
- `cy.runSimulation(strategyIndex, targetDrawIndex)` - Run a simulation
- `cy.waitForSimulationComplete(timeoutMs)` - Wait for simulation to complete

## Troubleshooting

### Database Connection Issues

If you see database connection errors:
1. Ensure PostgreSQL is running: `pg_isready`
2. Check database exists: `psql -l | grep numbers_evolution_e2e`
3. Verify DATABASE_URL matches your PostgreSQL setup

### Server Not Starting

If the server fails to start:
1. Check if port 4000 is available: `lsof -i :4000`
2. Verify `MIX_ENV=test_e2e` is set
3. Check server logs for errors

### Tests Failing

If tests fail:
1. Ensure server is running: `curl http://127.0.0.1:4000`
2. Check E2E endpoint: `curl -X POST http://127.0.0.1:4000/api/e2e/reset-db`
3. Verify `MIX_ENV=test_e2e` is set
4. Check Cypress screenshots in `cypress/screenshots/`
