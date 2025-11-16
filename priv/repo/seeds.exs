# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     NumbersEvolution.Repo.insert!(%NumbersEvolution.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias NumbersEvolution.{Repo, Draws}
alias NumbersEvolution.Draws.Draw

# Create sample Eurojackpot draws
IO.puts("Seeding Eurojackpot draws...")

# Recent draws from Nov 2024 (przykładowe dane)
sample_draws = [
  %{
    draw_date: ~D[2024-11-15],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 12, 23, 34, 50],
      "euro_numbers" => [3, 9]
    },
    source: "manual"
  },
  %{
    draw_date: ~D[2024-11-12],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 15, 28, 39, 47],
      "euro_numbers" => [2, 11]
    },
    source: "manual"
  },
  %{
    draw_date: ~D[2024-11-08],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 18, 25, 36, 44],
      "euro_numbers" => [1, 8]
    },
    source: "manual"
  },
  %{
    draw_date: ~D[2024-11-05],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 14, 21, 33, 48],
      "euro_numbers" => [4, 10]
    },
    source: "manual"
  },
  %{
    draw_date: ~D[2024-11-01],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 16, 27, 38, 45],
      "euro_numbers" => [5, 12]
    },
    source: "manual"
  },
  %{
    draw_date: ~D[2024-10-29],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 11, 24, 35, 46],
      "euro_numbers" => [6, 7]
    },
    source: "manual"
  },
  %{
    draw_date: ~D[2024-10-25],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 26, 37, 49],
      "euro_numbers" => [1, 9]
    },
    source: "manual"
  },
  %{
    draw_date: ~D[2024-10-22],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 22, 31, 42],
      "euro_numbers" => [3, 11]
    },
    source: "manual"
  },
  %{
    draw_date: ~D[2024-10-18],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 19, 29, 40, 48],
      "euro_numbers" => [2, 8]
    },
    source: "manual"
  },
  %{
    draw_date: ~D[2024-10-15],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 20, 30, 41, 50],
      "euro_numbers" => [4, 12]
    },
    source: "manual"
  }
]

Enum.each(sample_draws, fn draw_attrs ->
  case Draws.create_draw(draw_attrs) do
    {:ok, draw} ->
      IO.puts("✓ Created draw for #{draw.draw_date}")

    {:error, changeset} ->
      IO.puts("✗ Failed to create draw for #{draw_attrs.draw_date}")
      IO.inspect(changeset.errors)
  end
end)

IO.puts("\nSeeding completed!")
IO.puts("Total draws in database: #{Draws.count_draws()}")
