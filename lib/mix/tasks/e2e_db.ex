defmodule Mix.Tasks.E2eDb do
  @moduledoc """
  Tasks for managing E2E test database.

  This module provides tasks to reset and seed the E2E test database
  that can be called from Cypress tests.
  """

  use Mix.Task

  @shortdoc "Reset E2E test database"

  @impl Mix.Task
  def run(["reset"]) do
    # Start the application
    Mix.Task.run("app.start")

    # Drop and recreate database
    Mix.Task.run("ecto.drop", ["--quiet"])
    Mix.Task.run("ecto.create", ["--quiet"])
    Mix.Task.run("ecto.migrate", ["--quiet"])

    # Seed with test data
    Mix.Task.run("run", ["priv/repo/seeds.exs"])

    # Create test user for E2E tests
    create_test_user()

    IO.puts("E2E database reset complete")
  end

  @shortdoc "Seed E2E test database"

  def run(["seed"]) do
    Mix.Task.run("run", ["priv/repo/seeds.exs"])
    create_test_user()
    IO.puts("E2E database seeded")
  end

  @shortdoc "Create test user for E2E tests"

  def run(["create_test_user"]) do
    create_test_user()
    IO.puts("Test user created")
  end

  @shortdoc "Reset and seed E2E test database"

  def run([]) do
    run(["reset"])
  end

  @shortdoc "Show help"

  def run(["help"]) do
    IO.puts("""
    E2E Database Tasks:

    mix e2e_db reset          - Reset database (drop, create, migrate, seed)
    mix e2e_db seed           - Seed database with test data
    mix e2e_db create_test_user - Create test user for E2E tests
    mix e2e_db                - Same as reset
    mix e2e_db help           - Show this help
    """)
  end

  def run(_args) do
    run(["help"])
  end

  defp create_test_user do
    alias NumbersEvolution.Accounts

    # Create test user if doesn't exist
    case Accounts.get_user_by_email("test@example.com") do
      nil ->
        user_attrs = %{
          email: "test@example.com",
          password: "testpassword123",
          password_confirmation: "testpassword123"
        }

        case Accounts.register_user(user_attrs) do
          {:ok, _user} ->
            IO.puts("Test user created: test@example.com / testpassword123")

          {:error, changeset} ->
            IO.puts("Failed to create test user: #{inspect(changeset.errors)}")
        end

      _user ->
        IO.puts("Test user already exists")
    end
  end
end
