defmodule EventDefinition.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # FORCE L'INJECTION DES DOMAINES DANS L'ENVIRONNEMENT D'ASH ADMIN AU DÉMARRAGE
    Application.put_env(:ash_admin, :domains, [EventDefinition.Domain, EventDefinition.Accounts])

    children = [
      EventDefinitionWeb.Telemetry,
      EventDefinition.Repo,
      {DNSCluster, query: Application.get_env(:event_definition, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EventDefinition.PubSub},
      # Start a worker by calling: EventDefinition.Worker.start_link(arg)
      # {EventDefinition.Worker, arg},
      # Start to serve requests, typically the last entry
      EventDefinitionWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EventDefinition.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EventDefinitionWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
