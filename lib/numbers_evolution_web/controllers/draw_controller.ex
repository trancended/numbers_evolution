defmodule NumbersEvolutionWeb.DrawController do
  @moduledoc """
  Controller for historical lottery draws (public endpoints).
  """

  use NumbersEvolutionWeb, :controller

  alias NumbersEvolution.Draws

  action_fallback(NumbersEvolutionWeb.FallbackController)

  # GET /api/draws
  def index(conn, params) do
    opts = [
      game_type: params["game_type"],
      from_date: parse_date(params["from_date"]),
      to_date: parse_date(params["to_date"]),
      page: parse_int(params["page"], default: 1, min: 1),
      per_page: parse_int(params["per_page"], default: 20, min: 1, max: 100)
    ]

    draws = Draws.list_draws(opts)
    total_count = Draws.count_draws(opts)

    conn
    |> put_status(:ok)
    |> render(:index, draws: draws, meta: pagination_meta(opts, total_count))
  end

  # GET /api/draws/:id
  def show(conn, %{"id" => id}) do
    case get_draw_safe(id) do
      {:ok, draw} ->
        conn
        |> put_status(:ok)
        |> render(:show, draw: draw)

      {:error, _reason} = error ->
        error
    end
  end

  # GET /api/draws/latest
  def latest(conn, %{"game_type" => game_type}) do
    case Draws.get_latest_draw(game_type) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(NumbersEvolutionWeb.ErrorJSON)
        |> render(:error, message: "No draws found for game type: #{game_type}")

      draw ->
        conn
        |> put_status(:ok)
        |> render(:show, draw: draw)
    end
  end

  def latest(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, message: "Missing required parameter: game_type")
  end

  # GET /api/draws/analysis
  def analysis(conn, %{"game_type" => game_type} = params) do
    period = parse_int(params["period"], default: 32, min: 1, max: 100)

    analysis = Draws.analyze_hot_cold(game_type, period)

    if Enum.empty?(analysis.main_numbers.hot) do
      conn
      |> put_status(:not_found)
      |> put_view(NumbersEvolutionWeb.ErrorJSON)
      |> render(:error, message: "Insufficient draws for analysis")
    else
      conn
      |> put_status(:ok)
      |> render(:analysis, analysis: analysis, game_type: game_type, period: period)
    end
  end

  def analysis(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, message: "Missing required parameter: game_type")
  end

  ## Private Helpers

  defp get_draw_safe(id) do
    draw = Draws.get_draw!(id)
    {:ok, draw}
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

  defp parse_date(nil), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_date(_), do: nil

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
