defmodule Nostrex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Nostrex.Repo,
      # Start the Telemetry supervisor
      NostrexWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Nostrex.PubSub},
      # Start fast filter table manager
      Nostrex.FastFilterTableManager,
      # Start the Endpoint (http/https)
      NostrexWeb.Endpoint
      # Start a worker by calling: Nostrex.Worker.start_link(arg)
      # {Nostrex.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nostrex.Supervisor]
    Supervisor.start_link(children, opts)

    # Create ETS tables
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NostrexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
