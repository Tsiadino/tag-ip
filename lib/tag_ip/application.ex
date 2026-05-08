defmodule TagIp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TagIpWeb.Telemetry,
      TagIp.Repo,
      {DNSCluster, query: Application.get_env(:tag_ip, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TagIp.PubSub},
      # Start a worker by calling: TagIp.Worker.start_link(arg)
      # {TagIp.Worker, arg},
      # Start to serve requests, typically the last entry
      TagIpWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TagIp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TagIpWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
