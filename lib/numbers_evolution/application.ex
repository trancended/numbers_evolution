defmodule NumbersEvolution.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize ETS table for rate limiting
    :ets.new(:rate_limiter, [:set, :public, :named_table])
    :ets.insert(:rate_limiter, {:last_request, System.system_time(:second)})

    children = [
      NumbersEvolutionWeb.Telemetry,
      NumbersEvolution.Repo,
      {DNSCluster, query: Application.get_env(:numbers_evolution, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NumbersEvolution.PubSub},
      {Task.Supervisor, name: NumbersEvolution.TaskSupervisor, max_children: :infinity},
      # Start a worker by calling: NumbersEvolution.Worker.start_link(arg)
      # {NumbersEvolution.Worker, arg},
      # Start to serve requests, typically the last entry
      NumbersEvolutionWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NumbersEvolution.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      # Clean up orphaned simulations and start pending ones after Repo is ready (only in dev/prod)
      unless System.get_env("MIX_ENV") == "test" do
        :ok = cleanup_and_start_simulations_after_repo_ready()
      end

      # Setup E2E test database after Repo is ready
      # Note: E2E tests handle database setup via API endpoints

      {:ok, pid}
    end
  end

  defp cleanup_and_start_simulations_after_repo_ready do
    # Wait a bit for Repo to be ready, then cleanup orphaned simulations and start pending ones
    # Use Task.Supervisor to ensure Repo access
    Task.Supervisor.start_child(
      NumbersEvolution.TaskSupervisor,
      fn ->
        Process.sleep(2000)
        NumbersEvolution.Simulations.cleanup_orphaned_simulations()
        NumbersEvolution.Simulations.start_pending_simulations()
      end
    )

    :ok
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NumbersEvolutionWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
