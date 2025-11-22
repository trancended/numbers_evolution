defmodule NumbersEvolutionWeb.E2eController do
  use NumbersEvolutionWeb, :controller

  def reset_db(conn, _params) do
    try do
      # Reset database for E2E tests
      Mix.Task.run("e2e_db", ["reset"])

      conn
      |> put_status(:ok)
      |> json(%{status: "ok", message: "Database reset successfully"})
    rescue
      error ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: "Failed to reset database: #{inspect(error)}"})
    end
  end
end
