# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :nostrex,
  ecto_repos: [Nostrex.Repo]

# NostrexWeb.Handler is a custom handler copying Elixir.Plug.Handler with some extra logic
# for NIP 5

# Old settings were:
#  {"/", NostrexWeb.NostrSocket, []},
#  {:_, Phoenix.Endpoint.Cowboy2Handler, {NostrexWeb.Endpoint, []}},
dispatch = [
  {:_,
   [
     {:_, NostrexWeb.Handler, {NostrexWeb.Endpoint, []}}
   ]}
]

# Configures the endpoint
config :nostrex, NostrexWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: NostrexWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Nostrex.PubSub,
  live_view: [signing_salt: "NimhoO13"],
  http: [dispatch: dispatch]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
