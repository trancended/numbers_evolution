defmodule NumbersEvolution.Draws.ImporterTest do
  use NumbersEvolution.DataCase, async: true

  import Mox

  alias NumbersEvolution.Draws
  alias NumbersEvolution.Draws.Importer
  alias NumbersEvolution.HTTPClientMock

  setup :verify_on_exit!

  defp api_response(date \\ ~D[2026-06-09]) do
    %{
      "last" => %{
        "date" => %{"year" => date.year, "month" => date.month, "day" => date.day},
        "numbers" => [48, 1, 22, 39, 14],
        "euroNumbers" => [11, 8]
      }
    }
  end

  test "imports the latest draw with sorted numbers" do
    expect(HTTPClientMock, :get, fn url, _opts ->
      assert url =~ "lottoland"
      {:ok, %{status: 200, body: api_response()}}
    end)

    assert {:ok, :imported, draw} = Importer.import_latest()
    assert draw.draw_date == ~D[2026-06-09]
    assert draw.game_type == "eurojackpot"
    assert draw.source == "import"
    assert draw.numbers.main_numbers == [1, 14, 22, 39, 48]
    assert draw.numbers.euro_numbers == [8, 11]
  end

  test "second import of the same draw is idempotent" do
    expect(HTTPClientMock, :get, 2, fn _url, _opts ->
      {:ok, %{status: 200, body: api_response()}}
    end)

    assert {:ok, :imported, _draw} = Importer.import_latest()
    assert {:ok, :already_exists} = Importer.import_latest()

    draws = Draws.list_draws(game_type: "eurojackpot")
    assert length(draws) == 1
  end

  test "decodes JSON string bodies" do
    expect(HTTPClientMock, :get, fn _url, _opts ->
      {:ok, %{status: 200, body: Jason.encode!(api_response())}}
    end)

    assert {:ok, :imported, _draw} = Importer.import_latest()
  end

  test "returns error on unexpected payload" do
    expect(HTTPClientMock, :get, fn _url, _opts ->
      {:ok, %{status: 200, body: %{"unexpected" => true}}}
    end)

    assert {:error, :unexpected_payload} = Importer.import_latest()
  end

  test "returns error on HTTP failure" do
    expect(HTTPClientMock, :get, fn _url, _opts ->
      {:ok, %{status: 503, body: ""}}
    end)

    assert {:error, {:http_status, 503}} = Importer.import_latest()
  end

  test "returns error on transport failure" do
    expect(HTTPClientMock, :get, fn _url, _opts ->
      {:error, :timeout}
    end)

    assert {:error, :timeout} = Importer.import_latest()
  end
end
