defmodule NumbersEvolutionWeb.Plugs.RateLimiter do
  @moduledoc """
  Plug for rate limiting API requests.

  Uses ETS for fast in-memory tracking of request counts per user.
  Supports configurable limits and windows per route.
  """

  import Plug.Conn
  import Phoenix.Controller

  @table_name :rate_limiter

  def init(opts), do: opts

  def call(conn, _opts) do
    rate_limit_config = conn.private[:rate_limit]

    if rate_limit_config do
      apply_rate_limit(conn, rate_limit_config)
    else
      conn
    end
  end

  defp apply_rate_limit(conn, config) do
    user_id = conn.assigns.current_user.id
    scope = config[:scope]
    limit = config[:limit]
    window = config[:window]

    key = "rate_limit:#{scope}:#{user_id}"

    case check_and_increment(key, limit, window) do
      {:ok, remaining} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
        |> put_resp_header("x-ratelimit-reset", to_string(reset_time(window)))

      {:error, retry_after} ->
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_view(NumbersEvolutionWeb.ErrorJSON)
        |> render(:error, message: "Rate limit exceeded")
        |> halt()
    end
  end

  defp check_and_increment(key, limit, window) do
    now = System.system_time(:second)

    case :ets.lookup(@table_name, key) do
      [{^key, count, timestamp}] ->
        handle_existing_entry(key, limit, window, count, timestamp, now)

      [] ->
        :ets.insert(@table_name, {key, 1, now})
        {:ok, limit - 1}
    end
  end

  defp handle_existing_entry(key, limit, window, count, timestamp, now) do
    if now - timestamp > window do
      # Window expired, reset
      :ets.insert(@table_name, {key, 1, now})
      {:ok, limit - 1}
    else
      handle_within_window(key, limit, window, count, timestamp, now)
    end
  end

  defp handle_within_window(key, limit, window, count, timestamp, now) do
    if count < limit do
      :ets.update_counter(@table_name, key, {2, 1})
      {:ok, limit - count - 1}
    else
      retry_after = window - (now - timestamp)
      {:error, retry_after}
    end
  end

  defp reset_time(window) do
    System.system_time(:second) + window
  end

  @doc """
  Initializes the ETS table for rate limiting.

  Should be called in the application start.
  """
  def init_table do
    :ets.new(@table_name, [:named_table, :public, :set])
  end
end
