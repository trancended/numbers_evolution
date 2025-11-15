defmodule NumbersEvolution.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize ETS table for rate limiting
    NumbersEvolutionWeb.Plugs.RateLimiter.init_table()

    children = [
      NumbersEvolutionWeb.Telemetry,
      NumbersEvolution.Repo,
      {DNSCluster, query: Application.get_env(:numbers_evolution, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NumbersEvolution.PubSub},
      # Start a worker by calling: NumbersEvolution.Worker.start_link(arg)
      # {NumbersEvolution.Worker, arg},
      # Start to serve requests, typically the last entry
      NumbersEvolutionWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NumbersEvolution.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NumbersEvolutionWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
