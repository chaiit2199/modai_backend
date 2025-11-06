# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :modai_backend,
  ecto_repos: [ModaiBackend.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :modai_backend, ModaiBackendWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ModaiBackendWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ModaiBackend.PubSub,
  live_view: [signing_salt: "CVZlvgOH"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
#
# SMTP Configuration - uncomment and configure for real email sending
# config :modai_backend, ModaiBackend.Mailer,
#   adapter: Swoosh.Adapters.SMTP,
#   relay: "smtp.gmail.com",
#   username: System.get_env("SMTP_USERNAME"),
#   password: System.get_env("SMTP_PASSWORD"),
#   ssl: true,
#   tls: :if_available,
#   auth: :always,
#   port: 465,
#   retries: 2

# Default to Local adapter for development
config :modai_backend, ModaiBackend.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# JWT Configuration
config :modai_backend, ModaiBackendWeb.Guardian,
  issuer: "modai_backend",
  secret_key: "your-secret-key-change-in-production-use-mix-phx-gen-secret"

# CORS Configuration
config :modai_backend, ModaiBackendWeb.Plugs.CORS,
  allowed_origins: ["http://localhost:3000", "http://localhost:5173", "http://localhost:8080"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
