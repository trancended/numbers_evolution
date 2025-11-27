defmodule NumbersEvolution.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :numbers_evolution

  def migrate do
    load_app()

    for repo <- repos() do
      # For Fly.io, the database already exists, just run migrations
      IO.puts("Running migrations on existing database...")
      run_migrations_with_retry(repo)
    end

    # Run seeds after migrations
    IO.puts("Running database seeds...")
    seed()
  end

  def create_db do
    load_app()

    for repo <- repos() do
      # Try to create database if it doesn't exist
      create_database_if_needed(repo)
    end
  end

  defp create_database_if_needed(repo) do
    case Ecto.Migrator.with_repo(repo, fn _repo ->
           # This will work if connecting to default database
           :ok
         end) do
      {:ok, _, _} ->
        IO.puts("Database is accessible")

      {:error, _} ->
        IO.puts("Database connection failed - this is expected if database doesn't exist")
        # On Fly.io, database should already exist, so this shouldn't happen
    end
  end

  defp run_migrations_with_retry(repo, attempts \\ 5) do
    IO.puts("Attempting to run migrations... (attempt #{6 - attempts}/5)")

    case Ecto.Migrator.with_repo(repo, fn repo ->
           Ecto.Migrator.run(repo, :up, all: true)
         end) do
      {:ok, migrated, _} when is_list(migrated) ->
        IO.puts("Migrations completed successfully! Migrated #{length(migrated)} files.")

      {:ok, _, _} ->
        IO.puts("Migrations completed successfully!")

      {:error, reason} when attempts > 1 ->
        IO.puts("Migration failed: #{inspect(reason)}")
        IO.puts("Retrying in 10 seconds... (#{attempts - 1} attempts left)")
        :timer.sleep(10_000)
        run_migrations_with_retry(repo, attempts - 1)

      {:error, reason} ->
        IO.puts("Migration failed after all retries: #{inspect(reason)}")
        raise "Migration failed after #{6 - attempts} attempts"
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          seed_script = Path.join([:code.priv_dir(@app), "repo", "seeds.exs"])

          if File.exists?(seed_script) do
            Code.eval_file(seed_script)
          end
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
