defmodule NumbersEvolutionWeb.StrategyController do
  @moduledoc """
  Controller for strategy management.
  """

  use NumbersEvolutionWeb, :controller

  alias NumbersEvolution.Strategies

  action_fallback NumbersEvolutionWeb.FallbackController

  # GET /api/strategies
  def index(conn, params) do
    user = conn.assigns.current_user

    opts = [
      type: params["type"],
      status: params["status"],
      sort: params["sort"] || "inserted_at",
      order: params["order"] || "desc",
      page: parse_int(params["page"], default: 1, min: 1),
      per_page: parse_int(params["per_page"], default: 20, min: 1, max: 100)
    ]

    strategies = Strategies.list_strategies(user, opts)
    total_count = Strategies.count_strategies(user, opts)

    conn
    |> put_status(:ok)
    |> render(:index, strategies: strategies, meta: pagination_meta(opts, total_count))
  end

  # GET /api/strategies/:id
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case get_strategy_safe(user, id) do
      {:ok, _strategy} ->
        strategy_with_stats = Strategies.get_strategy_with_stats(user, id)

        conn
        |> put_status(:ok)
        |> render(:show, strategy: strategy_with_stats)

      {:error, _reason} = error ->
        error
    end
  end

  # POST /api/strategies
  def create(conn, %{"strategy" => strategy_params}) do
    user = conn.assigns.current_user

    case Strategies.create_strategy(user, strategy_params) do
      {:ok, strategy} ->
        conn
        |> put_status(:created)
        |> render(:show, strategy: strategy)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  # PATCH /api/strategies/:id
  def update(conn, %{"id" => id, "strategy" => strategy_params}) do
    user = conn.assigns.current_user

    with {:ok, _strategy} <- get_strategy_safe(user, id),
         {:ok, updated_strategy} <- Strategies.update_strategy(user, id, strategy_params) do
      conn
      |> put_status(:ok)
      |> render(:show, strategy: updated_strategy)
    else
      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> put_view(NumbersEvolutionWeb.ErrorJSON)
        |> render(:error,
          message:
            "AI-generated strategy rules cannot be modified. You can change the name or create a new strategy."
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, _reason} = error ->
        error
    end
  end

  # DELETE /api/strategies/:id
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, _strategy} <- get_strategy_safe(user, id),
         {:ok, _deleted_strategy} <- Strategies.delete_strategy(user, id) do
      send_resp(conn, :no_content, "")
    else
      {:error, _reason} = error -> error
    end
  end

  ## Private Helpers

  defp get_strategy_safe(user, id) do
    strategy = Strategies.get_strategy!(user, id)
    {:ok, strategy}
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
