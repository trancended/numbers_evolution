defmodule Mix.Tasks.Import.Draws do
  @shortdoc "Imports the latest Eurojackpot draw from the public API"

  @moduledoc """
  Fetches the most recent Eurojackpot draw and stores it in the database.

      mix import.draws

  Running it again for the same draw is a no-op (idempotent).
  """

  use Mix.Task

  alias NumbersEvolution.Draws.Importer

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case Importer.import_latest() do
      {:ok, :imported, draw} ->
        Mix.shell().info(
          "Imported Eurojackpot draw #{draw.draw_date}: " <>
            "#{Enum.join(draw.numbers.main_numbers, ", ")} + " <>
            "#{Enum.join(draw.numbers.euro_numbers, ", ")}"
        )

      {:ok, :already_exists} ->
        Mix.shell().info("Latest draw already imported - nothing to do")

      {:error, reason} ->
        Mix.shell().error("Import failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
