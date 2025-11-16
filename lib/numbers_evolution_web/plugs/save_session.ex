defmodule NumbersEvolutionWeb.Plugs.SaveSession do
  @moduledoc """
  Plug to save session token in cookie after login/register.
  This is used when redirecting from LiveView to ensure session is persisted.
  Also handles clearing session on logout.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      # Handle logout - clear session
      Map.get(conn.params, "logout") == "true" ->
        conn
        |> clear_session()

      # Handle login/register - save token
      token = Map.get(conn.params, "token") ->
        if is_binary(token) do
          conn
          |> put_session("user_token", token)
        else
          conn
        end

      # No action needed
      true ->
        conn
    end
  end
end
