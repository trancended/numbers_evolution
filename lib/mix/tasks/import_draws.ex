defmodule Mix.Tasks.Import.Draws do
  @shortdoc "Imports draws (Eurojackpot: latest, Lotto: full history backfill)"

  @moduledoc """
  Imports draws for each supported game and stores them in the database.

  Eurojackpot fetches the most recent draw from the Lottoland API. Lotto
  downloads the full mbnet.com.pl archive and automatically backfills every
  missing draw (including the latest one).

      mix import.draws          # imports all importable games
      mix import.draws lotto    # imports a single game

  Running it again is a no-op for already imported draws (idempotent).
  """

  use Mix.Task

  alias NumbersEvolution.Draws.Importer
  alias NumbersEvolution.Games

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    games =
      case args do
        [] -> Games.importable()
        [game_id | _] -> [Games.get!(game_id)]
      end

    results = Enum.map(games, &import_game/1)

    if Enum.any?(results, &(&1 == :error)) do
      exit({:shutdown, 1})
    end
  end

  defp import_game(game) do
    case Importer.import_latest(game.id) do
      {:ok, :imported, draw} ->
        Mix.shell().info("Imported #{game.label} draw #{draw.draw_date}: #{format_numbers(draw)}")
        :ok

      {:ok, :already_exists} ->
        Mix.shell().info("#{game.label}: latest draw already imported - nothing to do")
        :ok

      {:ok, :history_imported, %{imported: 0, total: total}} ->
        Mix.shell().info(
          "#{game.label}: all #{total} archive draws already imported - nothing to do"
        )

        :ok

      {:ok, :history_imported, %{imported: imported, total: total}} ->
        Mix.shell().info(
          "#{game.label}: imported #{imported} draws from the archive (#{total} total)"
        )

        :ok

      {:error, reason} ->
        Mix.shell().error("#{game.label}: import failed: #{inspect(reason)}")
        :error
    end
  end

  defp format_numbers(draw) do
    main = Enum.join(draw.numbers.main_numbers, ", ")

    case draw.numbers.euro_numbers do
      [] -> main
      euro -> main <> " + " <> Enum.join(euro, ", ")
    end
  end
end
