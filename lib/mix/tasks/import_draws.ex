defmodule Mix.Tasks.Import.Draws do
  @shortdoc "Imports the latest draws (Eurojackpot, Lotto) from the public API"

  @moduledoc """
  Fetches the most recent draw for each supported game and stores it in the database.

      mix import.draws          # imports all importable games
      mix import.draws lotto    # imports a single game

  Running it again for the same draw is a no-op (idempotent).
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
