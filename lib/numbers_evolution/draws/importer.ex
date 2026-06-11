defmodule NumbersEvolution.Draws.Importer do
  @moduledoc """
  Imports the latest Eurojackpot draw result from the public Lottoland API.

  The API exposes only the most recent draw, so the importer is meant to run
  after each drawing (Tuesday/Friday) - via the `mix import.draws` task or the
  button in the admin panel. The unique index on `(game_type, draw_date)`
  makes repeated imports idempotent.
  """

  alias NumbersEvolution.Draws

  @api_url "https://www.lottoland.com/api/drawings/euroJackpot"

  @type result ::
          {:ok, :imported, Draws.Draw.t()}
          | {:ok, :already_exists}
          | {:error, term()}

  @doc """
  Fetches and stores the latest Eurojackpot draw.

  Returns `{:ok, :imported, draw}` for a new draw, `{:ok, :already_exists}`
  when the draw was imported before, or `{:error, reason}`.
  """
  @spec import_latest() :: result()
  def import_latest do
    with {:ok, body} <- fetch_latest(),
         {:ok, attrs} <- parse_draw(body) do
      insert_draw(attrs)
    end
  end

  defp fetch_latest do
    case http_client().get(@api_url, []) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: 200, body: body}} when is_binary(body) -> Jason.decode(body)
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_draw(%{
         "last" => %{
           "date" => %{"year" => year, "month" => month, "day" => day},
           "numbers" => main_numbers,
           "euroNumbers" => euro_numbers
         }
       })
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

  defp parse_draw(_body), do: {:error, :unexpected_payload}

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
