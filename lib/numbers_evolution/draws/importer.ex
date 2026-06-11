defmodule NumbersEvolution.Draws.Importer do
  @moduledoc """
  Imports draw results for every game with an `import` configuration in
  `NumbersEvolution.Games`.

  Two source types are supported:

  - `:lottoland` (Eurojackpot) - the public Lottoland API exposing only the
    most recent draw, so the importer is meant to run after each drawing
  - `:archive` (Lotto) - a plain-text archive with the full draw history
    (mbnet.com.pl, one `nr. dd.mm.yyyy n,n,n,n,n,n` line per draw, updated
    after each drawing); every run automatically backfills all missing draws,
    including the latest one

  Run via the `mix import.draws` task or the buttons in the admin panel.
  The unique index on `(game_type, draw_date)` makes repeated imports
  idempotent.
  """

  alias NumbersEvolution.Draws
  alias NumbersEvolution.Games

  @lottoland_base_url "https://www.lottoland.com/api/drawings/"

  @type result ::
          {:ok, :imported, Draws.Draw.t()}
          | {:ok, :already_exists}
          | {:ok, :history_imported, %{imported: non_neg_integer(), total: non_neg_integer()}}
          | {:error, term()}

  @doc """
  Imports draws for the given game (default: Eurojackpot).

  Lottoland games fetch the latest draw and return `{:ok, :imported, draw}`
  or `{:ok, :already_exists}`. Archive games backfill the whole history and
  return `{:ok, :history_imported, %{imported: n, total: t}}` (`imported: 0`
  when everything was already in the database).
  """
  @spec import_latest(String.t()) :: result()
  def import_latest(game_id \\ Games.default_id()) do
    game = Games.get!(game_id)

    case game.import do
      %{type: :lottoland, api_path: api_path} -> import_from_lottoland(game, api_path)
      %{type: :archive, url: url} -> import_from_archive(game, url)
      _ -> {:error, {:import_not_supported, game.id}}
    end
  end

  ## Lottoland (latest draw only)

  defp import_from_lottoland(game, api_path) do
    with {:ok, body} <- fetch(@lottoland_base_url <> api_path),
         {:ok, body} <- decode_json(body),
         {:ok, attrs} <- parse_lottoland_draw(game, body) do
      insert_draw(attrs)
    end
  end

  defp decode_json(body) when is_map(body), do: {:ok, body}
  defp decode_json(body) when is_binary(body), do: Jason.decode(body)

  defp parse_lottoland_draw(
         %{id: "eurojackpot"},
         %{
           "last" => %{
             "date" => %{"year" => year, "month" => month, "day" => day},
             "numbers" => main_numbers,
             "euroNumbers" => euro_numbers
           }
         }
       )
       when length(main_numbers) == 5 and length(euro_numbers) == 2 do
    with {:ok, date} <- Date.new(year, month, day) do
      {:ok,
       %{
         draw_date: date,
         game_type: "eurojackpot",
         source: "import",
         numbers: %{
           main_numbers: Enum.sort(main_numbers),
           euro_numbers: Enum.sort(euro_numbers)
         }
       }}
    end
  end

  defp parse_lottoland_draw(_game, _body), do: {:error, :unexpected_payload}

  ## Archive (full history backfill)

  defp import_from_archive(game, url) do
    with {:ok, body} <- fetch(url),
         {:ok, entries} <- parse_archive(body) do
      existing_dates = Draws.draw_dates(game.id)

      imported =
        entries
        |> Enum.reject(fn {date, _numbers} -> MapSet.member?(existing_dates, date) end)
        |> Enum.uniq_by(fn {date, _numbers} -> date end)
        |> Enum.count(fn {date, numbers} -> insert_archive_draw(game, date, numbers) end)

      {:ok, :history_imported, %{imported: imported, total: length(entries)}}
    end
  end

  # Lines look like "7363. 09.06.2026 2,4,24,30,39,41"; unknown lines are skipped
  @archive_line ~r/^\s*\d+\.\s+(\d{2})\.(\d{2})\.(\d{4})\s+([\d,]+)\s*$/

  defp parse_archive(body) when is_binary(body) do
    entries =
      body
      |> String.split(["\n", "\r\n"], trim: true)
      |> Enum.flat_map(fn line ->
        with [_, day, month, year, numbers] <- Regex.run(@archive_line, line),
             {:ok, date} <-
               Date.new(
                 String.to_integer(year),
                 String.to_integer(month),
                 String.to_integer(day)
               ) do
          numbers = numbers |> String.split(",") |> Enum.map(&String.to_integer/1)
          [{date, Enum.sort(numbers)}]
        else
          _ -> []
        end
      end)

    if entries == [] do
      {:error, :unexpected_payload}
    else
      {:ok, entries}
    end
  end

  defp parse_archive(_body), do: {:error, :unexpected_payload}

  defp insert_archive_draw(game, date, numbers) do
    attrs = %{
      draw_date: date,
      game_type: game.id,
      source: "import",
      numbers: %{main_numbers: numbers, euro_numbers: []}
    }

    case insert_draw(attrs) do
      {:ok, :imported, _draw} ->
        true

      {:ok, :already_exists} ->
        false

      {:error, changeset} ->
        require Logger
        Logger.warning("Skipping invalid archive draw #{date}: #{inspect(changeset.errors)}")
        false
    end
  end

  ## Shared helpers

  defp fetch(url) do
    case http_client().get(url, []) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_draw(attrs) do
    case Draws.create_draw(attrs) do
      {:ok, draw} ->
        {:ok, :imported, draw}

      {:error, changeset} ->
        if duplicate_error?(changeset) do
          {:ok, :already_exists}
        else
          {:error, changeset}
        end
    end
  end

  defp duplicate_error?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {_msg, opts}} ->
      opts[:constraint] == :unique
    end)
  end

  defp http_client do
    Application.get_env(:numbers_evolution, :http_client, NumbersEvolution.HTTPClient.Impl)
  end
end
