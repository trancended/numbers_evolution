defmodule NumbersEvolutionWeb.SimulationController do
  @moduledoc """
  Controller for simulation management.
  """

  use NumbersEvolutionWeb, :controller

  alias NumbersEvolution.Simulations

  action_fallback NumbersEvolutionWeb.FallbackController

  # GET /api/simulations
  def index(conn, params) do
    user = conn.assigns.current_user

    opts = [
      status: params["status"],
      strategy_id: params["strategy_id"],
      page: parse_int(params["page"], default: 1, min: 1),
      per_page: parse_int(params["per_page"], default: 20, min: 1, max: 100)
    ]

    simulations = Simulations.list_simulations(user, opts)
    total_count = Simulations.count_simulations(user, opts)

    conn
    |> put_status(:ok)
    |> render(:index, simulations: simulations, meta: pagination_meta(opts, total_count))
  end

  # GET /api/simulations/:id
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case get_simulation_safe(user, id) do
      {:ok, _simulation} ->
        simulation_with_details = Simulations.get_simulation_with_details(user, id)

        conn
        |> put_status(:ok)
        |> render(:show, simulation: simulation_with_details)

      {:error, _reason} = error ->
        error
    end
  end

  # POST /api/simulations
  def create(conn, %{"simulation" => simulation_params}) do
    user = conn.assigns.current_user

    case Simulations.start_simulation(user, simulation_params) do
      {:ok, simulation} ->
        conn
        |> put_status(:accepted)
        |> render(:show, simulation: simulation)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, _reason} = error ->
        error
    end
  end

  # GET /api/simulations/:id/progress
  def progress(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case get_simulation_safe(user, id) do
      {:ok, _simulation} ->
        progress = Simulations.get_simulation_progress(user, id)

        conn
        |> put_status(:ok)
        |> render(:progress, progress: progress)

      {:error, _reason} = error ->
        error
    end
  end

  ## Private Helpers

  defp get_simulation_safe(user, id) do
    simulation = Simulations.get_simulation!(user, id)
    {:ok, simulation}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp parse_int(nil, opts), do: Keyword.get(opts, :default, 1)

  defp parse_int(value, opts) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        min = Keyword.get(opts, :min)
        max = Keyword.get(opts, :max)

        cond do
          min && int < min -> Keyword.get(opts, :default, min)
          max && int > max -> max
          true -> int
        end

      _ ->
        Keyword.get(opts, :default, 1)
    end
  end

  defp parse_int(value, _opts) when is_integer(value), do: value
  defp parse_int(_value, opts), do: Keyword.get(opts, :default, 1)

  defp pagination_meta(opts, total_count) do
    page = opts[:page]
    per_page = opts[:per_page]
    total_pages = ceil(total_count / per_page)

    %{
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end
end
