import Config

# Configure your database for E2E tests
config :numbers_evolution, NumbersEvolution.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "numbers_evolution_test_e2e",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Run server for E2E tests
config :numbers_evolution, NumbersEvolutionWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: "U0ZJ6WUkQ2V39V6Z6p9uiYu9Ylm0TAezBEhxUhigJRQKyCSp7KJ7dFB4MDQ251vG",
  server: true

# In E2E tests we don't send emails
config :numbers_evolution, NumbersEvolution.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Configure logger for E2E tests (more verbose than regular tests)
config :logger, level: :info

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Use real HTTP client for E2E tests (not mock)
config :numbers_evolution, :http_client, NumbersEvolution.HTTPClient.Impl
