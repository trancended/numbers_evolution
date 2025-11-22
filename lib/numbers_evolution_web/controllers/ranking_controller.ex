defmodule NumbersEvolutionWeb.RankingController do
  @moduledoc """
  Controller for strategy performance rankings.
  """

  use NumbersEvolutionWeb, :controller

  import Ecto.Query
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Strategies.Strategy

  action_fallback(NumbersEvolutionWeb.FallbackController)

  # GET /api/rankings/strategies
  def strategies(conn, params) do
    user = conn.assigns.current_user

    opts = [
      page: parse_int(params["page"], default: 1, min: 1),
      per_page: parse_int(params["per_page"], default: 20, min: 1, max: 100)
    ]

    rankings = get_strategy_rankings(user, opts)
    total_count = count_strategy_rankings(user)

    conn
    |> put_status(:ok)
    |> render(:strategies, rankings: rankings, meta: pagination_meta(opts, total_count))
  end

  ## Private Helpers

  defp get_strategy_rankings(user, opts) do
    page = opts[:page]
    per_page = opts[:per_page]
    offset = (page - 1) * per_page

    query =
      from(s in Strategy,
        where: s.user_id == ^user.id,
        where: s.status == :active,
        where: not is_nil(s.performance_score),
        left_join: sim in assoc(s, :simulations),
        where: sim.status == :success,
        group_by: s.id,
        select: %{
          id: s.id,
          name: s.name,
          type: s.type,
          performance_score: s.performance_score,
          simulations_count: count(sim.id),
          median_attempts:
            fragment(
              "percentile_cont(0.5) WITHIN GROUP (ORDER BY ?)",
              sim.attempts_count
            )
        },
        order_by: [desc: s.performance_score],
        limit: ^per_page,
        offset: ^offset
      )

    rankings = Repo.all(query)

    # Add rank
    Enum.with_index(rankings, offset + 1)
    |> Enum.map(fn {ranking, rank} ->
      Map.put(ranking, :rank, rank)
    end)
  end

  defp count_strategy_rankings(user) do
    from(s in Strategy,
      where: s.user_id == ^user.id,
      where: s.status == :active,
      where: not is_nil(s.performance_score)
    )
    |> Repo.aggregate(:count)
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
