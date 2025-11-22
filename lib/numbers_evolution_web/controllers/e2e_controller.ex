defmodule NumbersEvolutionWeb.E2eController do
  use NumbersEvolutionWeb, :controller

  alias NumbersEvolution.Repo

  def reset_db(conn, _params) do
    # Only allow in test_e2e environment
    if Mix.env() != :test_e2e do
      conn
      |> put_status(:forbidden)
      |> json(%{status: "error", message: "E2E endpoints only available in test_e2e environment"})
    else
      # Reset database for E2E tests
      try do
        # Get all tables except schema_migrations
        {:ok, result} =
          Ecto.Adapters.SQL.query(
            Repo,
            """
            SELECT tablename FROM pg_tables
            WHERE schemaname = 'public'
            AND tablename != 'schema_migrations'
            """
          )

        tables = result.rows |> Enum.map(&hd/1)

        # Truncate all tables
        if tables != [] do
          table_list = Enum.join(tables, ", ")
          Ecto.Adapters.SQL.query!(Repo, "TRUNCATE TABLE #{table_list} RESTART IDENTITY CASCADE")
        end

        # Create a test user
        {:ok, user} =
          NumbersEvolution.Accounts.register_user(%{
            email: "test@example.com",
            password: "testpassword123",
            password_confirmation: "testpassword123"
          })

        conn
        |> put_status(:ok)
        |> json(%{
          status: "ok",
          message: "Database reset successfully",
          test_user: %{id: user.id, email: user.email}
        })
      rescue
        e ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{status: "error", message: "Failed to reset database: #{inspect(e)}"})
      end
    end
  end
end
