defmodule NumbersEvolution.Draws.Importer do
  @moduledoc """
  Imports the latest draw results from the public Lottoland API.

  Supports every game with an `import` configuration in `NumbersEvolution.Games`
  (Eurojackpot and Lotto). The API exposes only the most recent draw, so the
  importer is meant to run after each drawing - via the `mix import.draws` task
  or the buttons in the admin panel. The unique index on `(game_type, draw_date)`
  makes repeated imports idempotent.
  """

  alias NumbersEvolution.Draws
  alias NumbersEvolution.Games

  @api_base_url "https://www.lottoland.com/api/drawings/"

  @type result ::
          {:ok, :imported, Draws.Draw.t()}
          | {:ok, :already_exists}
          | {:error, term()}

  @doc """
  Fetches and stores the latest draw for the given game (default: Eurojackpot).

  Returns `{:ok, :imported, draw}` for a new draw, `{:ok, :already_exists}`
  when the draw was imported before, or `{:error, reason}`.
  """
  @spec import_latest(String.t()) :: result()
  def import_latest(game_id \\ Games.default_id()) do
    game = Games.get!(game_id)

    with {:ok, api_path} <- import_path(game),
         {:ok, body} <- fetch_latest(api_path),
         {:ok, attrs} <- parse_draw(game, body) do
      insert_draw(attrs)
    end
  end

  defp import_path(%{import: %{api_path: api_path}}), do: {:ok, api_path}
  defp import_path(%{id: id}), do: {:error, {:import_not_supported, id}}

  defp fetch_latest(api_path) do
    case http_client().get(@api_base_url <> api_path, []) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: 200, body: body}} when is_binary(body) -> Jason.decode(body)
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_draw(
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

  defp parse_draw(
         %{id: "lotto"},
         %{
           "last" => %{
             "date" => %{"year" => year, "month" => month, "day" => day},
             "numbers" => main_numbers
           }
         }
       )
       when length(main_numbers) == 6 do
    with {:ok, date} <- Date.new(year, month, day) do
      {:ok,
       %{
         draw_date: date,
         game_type: "lotto",
         source: "import",
         numbers: %{
           main_numbers: Enum.sort(main_numbers),
           euro_numbers: []
         }
       }}
    end
  end

  defp parse_draw(_game, _body), do: {:error, :unexpected_payload}

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
