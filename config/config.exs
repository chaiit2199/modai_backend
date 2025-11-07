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

# Default to Local adapter for development
config :modai_backend, ModaiBackend.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
