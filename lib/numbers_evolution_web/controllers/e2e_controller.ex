defmodule NumbersEvolutionWeb.E2eController do
  use NumbersEvolutionWeb, :controller

  def reset_db(conn, _params) do
    # Reset database for E2E tests
    case :erlang.apply(&Mix.Task.run/2, ["e2e_db", ["reset"]]) do
      result when is_tuple(result) or result == :ok ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok", message: "Database reset successfully"})

      _ ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: "Failed to reset database"})
    end
  end
end
