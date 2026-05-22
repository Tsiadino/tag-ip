# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

import Config

# 1. CONFIGURATION GÉNÉRALE DE L'APPLICATION (Très Important !)
config :tag_ip,
  ecto_repos: [TagIp.Repo],
  # <-- REPLACÉ ICI : indispensable pour Ash 3.0
  ash_domains: [TagIp.Domain, TagIp.Accounts],
  generators: [timestamp_type: :utc_datetime]

# 2. CONFIGURATION D'ASH ADMIN
config :ash_admin,
  domains: [TagIp.Domain, TagIp.Accounts],
  show_sensitive_data_on_relationship_selection?: true

# Désactivation temporaire des policies pour éviter les blocages d'affichage
config :ash_admin, :authorization, enabled?: false

# 3. CONFIGURATION D'ASH AUTHENTICATION
config :ash_authentication_phoenix,
  auth_routes_prefix: "/auth"

# Configure the endpoint
config :tag_ip, TagIpWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TagIpWeb.ErrorHTML, json: TagIpWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TagIp.PubSub,
  live_view: [signing_salt: "Jj5+dlIz"]

# Configure the mailer
config :tag_ip, TagIp.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  tag_ip: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  tag_ip: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
