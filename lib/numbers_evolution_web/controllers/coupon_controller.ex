defmodule NumbersEvolutionWeb.CouponController do
  @moduledoc """
  Controller for coupon (number set) generation.
  """

  use NumbersEvolutionWeb, :controller

  alias NumbersEvolution.Strategies
  alias NumbersEvolution.Strategies.Generator

  action_fallback(NumbersEvolutionWeb.FallbackController)

  # POST /api/coupons/generate
  def generate(conn, %{
        "strategy_id" => strategy_id,
        "count" => count,
        "game_type" => game_type
      }) do
    user = conn.assigns.current_user

    with {:ok, count_int} <- parse_count(count),
         {:ok, strategy} <- get_strategy_safe(user, strategy_id),
         {:ok, coupons} <- generate_coupons(strategy, count_int) do
      conn
      |> put_status(:ok)
      |> render(:generate, coupons: coupons, game_type: game_type, strategy: strategy)
    else
      {:error, :invalid_count} ->
        conn
        |> put_status(:bad_request)
        |> put_view(NumbersEvolutionWeb.ErrorJSON)
        |> render(:error, message: "Count must be between 1 and 10")

      {:error, :generation_failed} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(NumbersEvolutionWeb.ErrorJSON)
        |> render(:error, message: "Cannot generate unique coupons with these rules")

      {:error, _reason} = error ->
        error
    end
  end

  def generate(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, message: "Missing required parameters: strategy_id, count, game_type")
  end

  # POST /api/coupons/generate/top
  def generate_from_top(conn, %{"count" => count, "game_type" => game_type}) do
    user = conn.assigns.current_user

    with {:ok, count_int} <- parse_count(count),
         {:ok, top_strategy} <- get_top_strategy(user),
         {:ok, coupons} <- generate_coupons(top_strategy, count_int) do
      conn
      |> put_status(:ok)
      |> render(:generate, coupons: coupons, game_type: game_type, strategy: top_strategy)
    else
      {:error, :no_strategies} ->
        conn
        |> put_status(:not_found)
        |> put_view(NumbersEvolutionWeb.ErrorJSON)
        |> render(:error, message: "No strategies with simulations found")

      {:error, _reason} = error ->
        error
    end
  end

  def generate_from_top(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, message: "Missing required parameters: count, game_type")
  end

  ## Private Helpers

  defp get_strategy_safe(user, id) do
    strategy = Strategies.get_strategy!(user, id)
    {:ok, strategy}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp get_top_strategy(user) do
    import Ecto.Query

    query =
      from(s in NumbersEvolution.Strategies.Strategy,
        where: s.user_id == ^user.id,
        where: s.status == :active,
        where: not is_nil(s.performance_score),
        order_by: [desc: s.performance_score],
        limit: 1
      )

    case NumbersEvolution.Repo.one(query) do
      nil -> {:error, :no_strategies}
      strategy -> {:ok, strategy}
    end
  end

  defp parse_count(count) when is_binary(count) do
    case Integer.parse(count) do
      {int, ""} when int >= 1 and int <= 10 -> {:ok, int}
      _ -> {:error, :invalid_count}
    end
  end

  defp parse_count(count) when is_integer(count) and count >= 1 and count <= 10 do
    {:ok, count}
  end

  defp parse_count(_), do: {:error, :invalid_count}

  defp generate_coupons(strategy, count) do
    coupons =
      Enum.reduce_while(1..count, [], fn _i, acc ->
        process_coupon_generation(strategy, acc, count)
      end)

    format_coupons_result(coupons)
  end

  defp process_coupon_generation(strategy, acc, count) do
    case Generator.generate_numbers(strategy) do
      {:ok, numbers} ->
        coupon = build_coupon(numbers)
        continue_or_halt(coupon, acc, count)

      {:error, _reason} ->
        {:halt, {:error, :generation_failed}}
    end
  end

  defp build_coupon(numbers) do
    %{
      main: numbers.main,
      euro: numbers.euro
    }
  end

  defp continue_or_halt(coupon, acc, count) do
    if length(acc) < count do
      {:cont, [coupon | acc]}
    else
      {:halt, acc}
    end
  end

  defp format_coupons_result({:error, reason}), do: {:error, reason}

  defp format_coupons_result(list) when is_list(list) do
    {:ok, Enum.reverse(list)}
  end
end
