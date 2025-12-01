import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :numbers_evolution, NumbersEvolution.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  database: "numbers_evolution_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :numbers_evolution, NumbersEvolutionWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "U0ZJ6WUkQ2V39V6Z6p9uiYu9Ylm0TAezBEhxUhigJRQKyCSp7KJ7dFB4MDQ251vG",
  server: false

# In test we don't send emails
config :numbers_evolution, NumbersEvolution.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Suppress all log messages during test for clean dot-only output
config :logger, level: :emergency

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure admin user email for tests
config :numbers_evolution, :admin_user, System.get_env("ADMIN_USER") || "aa@aa.aa"

# Configure mocks for testing
config :numbers_evolution, :http_client, NumbersEvolution.HTTPClientMock
