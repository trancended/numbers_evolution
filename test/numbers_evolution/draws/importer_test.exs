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

  describe "lotto archive" do
    @archive_body """
    1. 27.01.1957 8,12,31,39,43,45
    2. 03.02.1957 5,10,11,22,25,27
    7363. 09.06.2026 41,2,24,30,4,39
    """

    test "backfills the full archive with sorted numbers and no euro numbers" do
      expect(HTTPClientMock, :get, fn url, _opts ->
        assert url =~ "mbnet.com.pl/dl.txt"
        {:ok, %{status: 200, body: @archive_body}}
      end)

      assert {:ok, :history_imported, %{imported: 3, total: 3}} =
               Importer.import_latest("lotto")

      draws = Draws.list_draws(game_type: "lotto")
      assert length(draws) == 3

      latest = Draws.get_latest_draw("lotto")
      assert latest.draw_date == ~D[2026-06-09]
      assert latest.source == "import"
      assert latest.numbers.main_numbers == [2, 4, 24, 30, 39, 41]
      assert latest.numbers.euro_numbers == []
    end

    test "second import only backfills missing draws (idempotent)" do
      expect(HTTPClientMock, :get, fn _url, _opts ->
        {:ok, %{status: 200, body: @archive_body}}
      end)

      assert {:ok, :history_imported, %{imported: 3, total: 3}} =
               Importer.import_latest("lotto")

      new_archive = @archive_body <> "7364. 11.06.2026 1,7,13,21,33,44\n"

      expect(HTTPClientMock, :get, fn _url, _opts ->
        {:ok, %{status: 200, body: new_archive}}
      end)

      assert {:ok, :history_imported, %{imported: 1, total: 4}} =
               Importer.import_latest("lotto")

      expect(HTTPClientMock, :get, fn _url, _opts ->
        {:ok, %{status: 200, body: new_archive}}
      end)

      assert {:ok, :history_imported, %{imported: 0, total: 4}} =
               Importer.import_latest("lotto")

      assert length(Draws.list_draws(game_type: "lotto")) == 4
    end

    test "skips malformed lines and invalid draws" do
      body = """
      garbage header
      1. 27.01.1957 8,12,31,39,43,45
      2. 03.02.1957 5,10,11,22,25
      3. 10.02.1957 18,19,20,26,45,99
      """

      expect(HTTPClientMock, :get, fn _url, _opts ->
        {:ok, %{status: 200, body: body}}
      end)

      assert {:ok, :history_imported, %{imported: 1, total: 3}} =
               Importer.import_latest("lotto")

      assert length(Draws.list_draws(game_type: "lotto")) == 1
    end

    test "lotto and eurojackpot draws on the same date can coexist" do
      expect(HTTPClientMock, :get, fn _url, _opts ->
        {:ok, %{status: 200, body: api_response()}}
      end)

      expect(HTTPClientMock, :get, fn _url, _opts ->
        {:ok, %{status: 200, body: "7363. 09.06.2026 2,4,24,30,39,41\n"}}
      end)

      expect(HTTPClientMock, :get, fn _url, _opts ->
        {:ok, %{status: 200, body: api_response()}}
      end)

      assert {:ok, :imported, _draw} = Importer.import_latest()
      assert {:ok, :history_imported, %{imported: 1}} = Importer.import_latest("lotto")
      assert {:ok, :already_exists} = Importer.import_latest()
    end

    test "returns error when the archive body is not parseable" do
      expect(HTTPClientMock, :get, fn _url, _opts ->
        {:ok, %{status: 200, body: "<html>not an archive</html>"}}
      end)

      assert {:error, :unexpected_payload} = Importer.import_latest("lotto")
    end

    test "returns error on HTTP failure for the archive" do
      expect(HTTPClientMock, :get, fn _url, _opts ->
        {:ok, %{status: 503, body: ""}}
      end)

      assert {:error, {:http_status, 503}} = Importer.import_latest("lotto")
    end
  end
end
