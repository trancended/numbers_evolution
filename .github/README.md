# GitHub Actions CI/CD

This directory contains GitHub Actions workflows for continuous integration and deployment.

## Workflows

### CI/CD Pipeline (`ci.yml`)

This workflow runs on every push and pull request to `main` and `e2e_cicd` branches.

#### Jobs

1. **Test & Format Check**
   - Checks code formatting with `mix format --check-formatted`
   - Compiles the code with warnings as errors
   - Runs unit tests with `mix test`

2. **E2E Tests**
   - Sets up PostgreSQL database
   - Starts Phoenix server in `test_e2e` environment
   - Runs Cypress E2E tests
   - Uploads screenshots and videos on failure

## Environment Configuration

The CI uses the following versions (must match local development):
- **Elixir**: 1.19.3
- **Erlang/OTP**: 28.1
- **Node.js**: 20.x
- **PostgreSQL**: 16

These versions are also specified in `.tool-versions` for local development consistency.

## Database Setup

The E2E tests use a separate database (`numbers_evolution_e2e`) to avoid conflicts with regular tests. The database is automatically:
1. Created with `mix ecto.create`
2. Migrated with `mix ecto.migrate`
3. Reset before each test via the `/api/e2e/reset-db` endpoint

## Troubleshooting

### Formatter Failures

If you see formatter failures in CI but not locally, ensure you're using the same Elixir version:

```bash
elixir --version
# Should show: Elixir 1.19.3 (compiled with Erlang/OTP 28)
```

To fix formatting issues:
```bash
mix format
```

### E2E Test Failures

If E2E tests fail with connection errors:
1. Check that the Phoenix server is starting correctly in CI logs
2. Verify the database is accessible
3. Check the uploaded Phoenix logs artifact for error details

### Local E2E Testing

To run E2E tests locally:

```bash
# Terminal 1: Start the server
MIX_ENV=test_e2e mix phx.server

# Terminal 2: Run Cypress tests
npm run cypress:run
# or for interactive mode:
npm run cypress:open
```

## Artifacts

On test failure, the following artifacts are uploaded:
- Cypress screenshots
- Cypress videos
- Phoenix server logs

These can be downloaded from the GitHub Actions run page.

