import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :hub, Hub.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "hub_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :hub, :sql_sandbox, true

config :hub, HubWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "SnzpOnOfHMa7/4G3GmTIWJnoDLutwukC4LjTTA3BncDlmnBbzZ6RYB99OXFeTOFq",
  server: false

# In test we don't send emails
config :hub, Hub.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :hub, Oban, testing: :manual

config :hub, :zoom,
  account_id: nil,
  client_id: nil,
  client_secret: nil,
  webhook_secret: "test-secret"

config :hub, :claude,
  api_key: "test-key",
  model: "claude-sonnet-4-20250514"
