defmodule NumbersEvolution.Draws.AutoImporter do
  @moduledoc """
  Periodically imports draws for every importable game.

  Runs shortly after application boot and then every few hours, so a fresh
  deployment automatically backfills the full Lotto archive and keeps both
  games up to date without any manual action. All imports are idempotent
  (unique index on `(game_type, draw_date)`), so concurrent machines or
  restarts are safe.

  Enabled via `config :numbers_evolution, auto_import_draws: true`
  (dev and prod; disabled in tests).
  """

  use GenServer

  require Logger

  alias NumbersEvolution.Draws.Importer
  alias NumbersEvolution.Games

  @initial_delay :timer.seconds(10)
  @interval :timer.hours(6)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Process.send_after(self(), :import, @initial_delay)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:import, state) do
    import_all()
    Process.send_after(self(), :import, @interval)
    {:noreply, state}
  end

  defp import_all do
    Enum.each(Games.importable(), fn game ->
      case Importer.import_latest(game.id) do
        {:ok, :imported, draw} ->
          Logger.info("AutoImporter: imported #{game.label} draw #{draw.draw_date}")

        {:ok, :already_exists} ->
          :ok

        {:ok, :history_imported, %{imported: 0}} ->
          :ok

        {:ok, :history_imported, %{imported: imported, total: total}} ->
          Logger.info(
            "AutoImporter: imported #{imported} #{game.label} draws from the archive (#{total} total)"
          )

        {:error, reason} ->
          Logger.warning("AutoImporter: #{game.label} import failed: #{inspect(reason)}")
      end
    end)
  rescue
    e -> Logger.error("AutoImporter: unexpected error: #{Exception.message(e)}")
  end
end
