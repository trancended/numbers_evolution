defmodule NumbersEvolution.Draws.LottoDrawsTest do
  use NumbersEvolution.DataCase, async: true

  alias NumbersEvolution.Draws

  defp lotto_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        draw_date: ~D[2026-06-09],
        game_type: "lotto",
        source: "manual",
        numbers: %{main_numbers: [2, 4, 24, 30, 39, 41], euro_numbers: []}
      },
      overrides
    )
  end

  test "creates a lotto draw with 6 main numbers and no euro numbers" do
    assert {:ok, draw} = Draws.create_draw(lotto_attrs())
    assert draw.game_type == "lotto"
    assert draw.numbers.main_numbers == [2, 4, 24, 30, 39, 41]
    assert draw.numbers.euro_numbers == []
  end

  test "rejects a lotto draw with 5 main numbers" do
    attrs = lotto_attrs(%{numbers: %{main_numbers: [2, 4, 24, 30, 39], euro_numbers: []}})

    assert {:error, changeset} = Draws.create_draw(attrs)
    assert %{numbers: %{main_numbers: [error]}} = errors_on(changeset)
    assert error =~ "exactly 6"
  end

  test "rejects a lotto draw with main numbers above 49" do
    attrs = lotto_attrs(%{numbers: %{main_numbers: [2, 4, 24, 30, 39, 50], euro_numbers: []}})

    assert {:error, changeset} = Draws.create_draw(attrs)
    assert %{numbers: %{main_numbers: [error]}} = errors_on(changeset)
    assert error =~ "1-49"
  end

  test "rejects a lotto draw with euro numbers" do
    attrs =
      lotto_attrs(%{numbers: %{main_numbers: [2, 4, 24, 30, 39, 41], euro_numbers: [1, 2]}})

    assert {:error, changeset} = Draws.create_draw(attrs)
    assert %{numbers: %{euro_numbers: [error]}} = errors_on(changeset)
    assert error =~ "empty"
  end

  test "eurojackpot draws still require 5 main + 2 euro numbers" do
    attrs = %{
      draw_date: ~D[2026-06-09],
      game_type: "eurojackpot",
      source: "manual",
      numbers: %{main_numbers: [1, 14, 22, 39, 48], euro_numbers: [8, 11]}
    }

    assert {:ok, draw} = Draws.create_draw(attrs)
    assert draw.numbers.euro_numbers == [8, 11]

    missing_euro = %{attrs | numbers: %{main_numbers: [1, 14, 22, 39, 48], euro_numbers: []}}
    assert {:error, _changeset} = Draws.create_draw(missing_euro)
  end
end
