defmodule Robosplore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RobosploreWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:robosplore, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Robosplore.PubSub},
      {DynamicSupervisor, name: Robosplore.DynamicSupervisor, strategy: :one_for_one},
      # Start a worker by calling: Robosplore.Worker.start_link(arg)
      # {Robosplore.Worker, arg},
      # Start to serve requests, typically the last entry
      RobosploreWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Robosplore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RobosploreWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
