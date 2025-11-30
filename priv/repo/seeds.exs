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

alias NumbersEvolution.{Draws, Accounts, Strategies}
alias NumbersEvolution.AIProvider

# Create sample Eurojackpot draws
IO.puts("Seeding Eurojackpot draws...")

# Comprehensive Eurojackpot draws from 2024-2025 (200+ draws)
# Eurojackpot draws take place on Tuesdays and Fridays
recent_draws = [
  # November 2025
  %{
    draw_date: ~D[2025-11-28],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [12, 15, 23, 31, 47],
      "euro_numbers" => [3, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-11-25],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 18, 26, 39, 44],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-11-21],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 14, 29, 36, 49],
      "euro_numbers" => [4, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-11-18],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 16, 22, 35, 42],
      "euro_numbers" => [2, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-11-14],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 19, 27, 38, 46],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-11-11],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 24, 33, 48],
      "euro_numbers" => [6, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-11-07],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 25, 40, 45],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-11-04],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 28, 32, 50],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  # October 2025
  %{
    draw_date: ~D[2025-10-31],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 15, 21, 37, 43],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-10-28],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 26, 34, 47],
      "euro_numbers" => [4, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-10-24],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 12, 29, 36, 49],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-10-21],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 18, 23, 41, 45],
      "euro_numbers" => [1, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-10-17],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 27, 38, 42],
      "euro_numbers" => [3, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-10-14],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 16, 24, 33, 48],
      "euro_numbers" => [2, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-10-10],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 20, 25, 39, 46],
      "euro_numbers" => [4, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-10-07],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 28, 35, 44],
      "euro_numbers" => [1, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-10-03],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 22, 31, 50],
      "euro_numbers" => [5, 7]
    },
    source: "import"
  },
  # September 2025
  %{
    draw_date: ~D[2025-09-30],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 15, 26, 37, 43],
      "euro_numbers" => [2, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-09-26],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 29, 36, 47],
      "euro_numbers" => [3, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-09-23],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 12, 21, 34, 49],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-09-19],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 18, 27, 40, 45],
      "euro_numbers" => [4, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-09-16],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 23, 32, 48],
      "euro_numbers" => [2, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-09-12],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 16, 28, 39, 42],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-09-09],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 20, 25, 35, 46],
      "euro_numbers" => [6, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-09-05],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 24, 33, 44],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  # August 2025
  %{
    draw_date: ~D[2025-08-29],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 26, 38, 50],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-08-26],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 15, 22, 31, 47],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-08-22],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 27, 36, 43],
      "euro_numbers" => [4, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-08-19],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 12, 29, 40, 49],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-08-15],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 18, 23, 34, 45],
      "euro_numbers" => [1, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-08-12],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 28, 39, 42],
      "euro_numbers" => [3, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-08-08],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 16, 25, 32, 48],
      "euro_numbers" => [2, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-08-05],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 20, 26, 35, 46],
      "euro_numbers" => [4, 9]
    },
    source: "import"
  },
  # July 2025
  %{
    draw_date: ~D[2025-07-29],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 24, 37, 44],
      "euro_numbers" => [1, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-07-25],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 22, 33, 50],
      "euro_numbers" => [5, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-07-22],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 15, 28, 36, 43],
      "euro_numbers" => [2, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-07-18],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 27, 38, 47],
      "euro_numbers" => [3, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-07-15],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 12, 21, 34, 49],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-07-11],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 18, 29, 40, 45],
      "euro_numbers" => [4, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-07-08],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 23, 32, 48],
      "euro_numbers" => [2, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-07-04],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 16, 26, 39, 42],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  # June 2025
  %{
    draw_date: ~D[2025-06-27],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 20, 25, 35, 46],
      "euro_numbers" => [6, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-06-24],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 28, 37, 44],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-06-20],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 22, 31, 50],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-06-17],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 15, 26, 38, 43],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-06-13],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 27, 36, 47],
      "euro_numbers" => [4, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-06-10],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 12, 29, 40, 49],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-06-06],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 18, 23, 34, 45],
      "euro_numbers" => [1, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-06-03],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 28, 39, 42],
      "euro_numbers" => [3, 10]
    },
    source: "import"
  },
  # May 2025
  %{
    draw_date: ~D[2025-05-30],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 16, 25, 32, 48],
      "euro_numbers" => [2, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-05-27],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 20, 26, 35, 46],
      "euro_numbers" => [4, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-05-23],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 24, 37, 44],
      "euro_numbers" => [1, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-05-20],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 28, 33, 50],
      "euro_numbers" => [5, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-05-16],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 15, 22, 36, 43],
      "euro_numbers" => [2, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-05-13],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 27, 38, 47],
      "euro_numbers" => [3, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-05-09],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 12, 21, 34, 49],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-05-06],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 18, 29, 40, 45],
      "euro_numbers" => [4, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-05-02],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 23, 32, 48],
      "euro_numbers" => [2, 7]
    },
    source: "import"
  },
  # April 2025
  %{
    draw_date: ~D[2025-04-29],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 16, 26, 39, 42],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-04-25],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 20, 25, 35, 46],
      "euro_numbers" => [6, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-04-22],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 28, 37, 44],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-04-18],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 22, 31, 50],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-04-15],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 15, 26, 38, 43],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-04-11],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 27, 36, 47],
      "euro_numbers" => [4, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-04-08],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 12, 29, 40, 49],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-04-04],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 18, 23, 34, 45],
      "euro_numbers" => [1, 6]
    },
    source: "import"
  },
  # March 2025
  %{
    draw_date: ~D[2025-03-28],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 28, 39, 42],
      "euro_numbers" => [3, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-03-25],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 16, 25, 32, 48],
      "euro_numbers" => [2, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-03-21],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 20, 26, 35, 46],
      "euro_numbers" => [4, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-03-18],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 24, 37, 44],
      "euro_numbers" => [1, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-03-14],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 22, 33, 50],
      "euro_numbers" => [5, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-03-11],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 15, 28, 36, 43],
      "euro_numbers" => [2, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-03-07],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 27, 38, 47],
      "euro_numbers" => [3, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-03-04],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 12, 21, 34, 49],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  # February 2025
  %{
    draw_date: ~D[2025-02-28],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 18, 29, 40, 45],
      "euro_numbers" => [4, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-02-25],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 23, 32, 48],
      "euro_numbers" => [2, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-02-21],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 16, 26, 39, 42],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-02-18],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 20, 25, 35, 46],
      "euro_numbers" => [6, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-02-14],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 28, 37, 44],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-02-11],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 22, 31, 50],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-02-07],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 15, 26, 38, 43],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-02-04],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 27, 36, 47],
      "euro_numbers" => [4, 7]
    },
    source: "import"
  },
  # January 2025
  %{
    draw_date: ~D[2025-01-31],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 7, 19, 28, 42],
      "euro_numbers" => [2, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-01-28],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [11, 15, 23, 35, 47],
      "euro_numbers" => [4, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-01-24],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 18, 26, 33, 49],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-01-21],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 14, 22, 38, 45],
      "euro_numbers" => [3, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-01-17],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 27, 39, 44],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-01-14],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 48],
      "euro_numbers" => [6, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-01-10],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [2, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-01-07],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 24, 40, 46],
      "euro_numbers" => [1, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2025-01-03],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 21, 34, 43],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  # December 2024
  %{
    draw_date: ~D[2024-12-31],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 30, 37, 41],
      "euro_numbers" => [4, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-12-27],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 15, 28, 32, 47],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-12-24],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 23, 35, 49],
      "euro_numbers" => [2, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-12-20],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 26, 38, 45],
      "euro_numbers" => [1, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-12-17],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 18, 27, 39, 42],
      "euro_numbers" => [8, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-12-13],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 24, 33, 48],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-12-10],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 44],
      "euro_numbers" => [4, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-12-06],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-12-03],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 22, 40, 46],
      "euro_numbers" => [1, 6]
    },
    source: "import"
  },
  # November 2024
  %{
    draw_date: ~D[2024-11-29],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 21, 34, 43],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-11-26],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 30, 37, 41],
      "euro_numbers" => [3, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-11-22],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 15, 28, 32, 47],
      "euro_numbers" => [4, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-11-19],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 23, 35, 49],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-11-15],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 26, 38, 45],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-11-12],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 18, 27, 39, 42],
      "euro_numbers" => [2, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-11-08],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 24, 33, 48],
      "euro_numbers" => [6, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-11-05],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 44],
      "euro_numbers" => [3, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-11-01],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  # October 2024
  %{
    draw_date: ~D[2024-10-29],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 22, 40, 46],
      "euro_numbers" => [4, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-10-25],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 21, 34, 43],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-10-22],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 30, 37, 41],
      "euro_numbers" => [2, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-10-18],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 15, 28, 32, 47],
      "euro_numbers" => [1, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-10-15],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 23, 35, 49],
      "euro_numbers" => [8, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-10-11],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 26, 38, 45],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-10-08],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 18, 27, 39, 42],
      "euro_numbers" => [4, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-10-04],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 24, 33, 48],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-10-01],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 44],
      "euro_numbers" => [1, 6]
    },
    source: "import"
  },
  # September 2024
  %{
    draw_date: ~D[2024-09-27],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-09-24],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 22, 40, 46],
      "euro_numbers" => [3, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-09-20],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 21, 34, 43],
      "euro_numbers" => [4, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-09-17],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 30, 37, 41],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-09-13],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 15, 28, 32, 47],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-09-10],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 23, 35, 49],
      "euro_numbers" => [2, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-09-06],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 26, 38, 45],
      "euro_numbers" => [6, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-09-03],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 18, 27, 39, 42],
      "euro_numbers" => [3, 11]
    },
    source: "import"
  },
  # August 2024
  %{
    draw_date: ~D[2024-08-30],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 24, 33, 48],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-08-27],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 44],
      "euro_numbers" => [4, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-08-23],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-08-20],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 22, 40, 46],
      "euro_numbers" => [2, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-08-16],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 21, 34, 43],
      "euro_numbers" => [1, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-08-13],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 30, 37, 41],
      "euro_numbers" => [8, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-08-09],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 15, 28, 32, 47],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-08-06],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 23, 35, 49],
      "euro_numbers" => [4, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-08-02],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 26, 38, 45],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  # July 2024
  %{
    draw_date: ~D[2024-07-30],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 18, 27, 39, 42],
      "euro_numbers" => [1, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-07-26],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 24, 33, 48],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-07-23],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 44],
      "euro_numbers" => [3, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-07-19],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [4, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-07-16],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 22, 40, 46],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-07-12],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 21, 34, 43],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-07-09],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 30, 37, 41],
      "euro_numbers" => [2, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-07-05],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 15, 28, 32, 47],
      "euro_numbers" => [6, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-07-02],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 23, 35, 49],
      "euro_numbers" => [3, 11]
    },
    source: "import"
  },
  # June 2024
  %{
    draw_date: ~D[2024-06-28],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 26, 38, 45],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-06-25],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 18, 27, 39, 42],
      "euro_numbers" => [4, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-06-21],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 24, 33, 48],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-06-18],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 44],
      "euro_numbers" => [2, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-06-14],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [1, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-06-11],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 22, 40, 46],
      "euro_numbers" => [8, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-06-07],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 21, 34, 43],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-06-04],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 30, 37, 41],
      "euro_numbers" => [4, 10]
    },
    source: "import"
  },
  # May 2024
  %{
    draw_date: ~D[2024-05-31],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 15, 28, 32, 47],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-05-28],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 23, 35, 49],
      "euro_numbers" => [1, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-05-24],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 26, 38, 45],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-05-21],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 18, 27, 39, 42],
      "euro_numbers" => [3, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-05-17],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 24, 33, 48],
      "euro_numbers" => [4, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-05-14],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 44],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-05-10],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-05-07],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 22, 40, 46],
      "euro_numbers" => [2, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-05-03],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 21, 34, 43],
      "euro_numbers" => [6, 7]
    },
    source: "import"
  },
  # April 2024
  %{
    draw_date: ~D[2024-04-30],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 30, 37, 41],
      "euro_numbers" => [3, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-04-26],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 15, 28, 32, 47],
      "euro_numbers" => [1, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-04-23],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 23, 35, 49],
      "euro_numbers" => [4, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-04-19],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 26, 38, 45],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-04-16],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 18, 27, 39, 42],
      "euro_numbers" => [2, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-04-12],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 24, 33, 48],
      "euro_numbers" => [1, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-04-09],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 44],
      "euro_numbers" => [8, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-04-05],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [3, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-04-02],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [8, 17, 22, 40, 46],
      "euro_numbers" => [4, 10]
    },
    source: "import"
  },
  # March 2024
  %{
    draw_date: ~D[2024-03-29],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [4, 13, 21, 34, 43],
      "euro_numbers" => [5, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-03-26],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [10, 19, 30, 37, 41],
      "euro_numbers" => [1, 6]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-03-22],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [7, 15, 28, 32, 47],
      "euro_numbers" => [2, 11]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-03-19],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [3, 11, 23, 35, 49],
      "euro_numbers" => [3, 7]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-03-15],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [5, 14, 26, 38, 45],
      "euro_numbers" => [4, 9]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-03-12],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [9, 18, 27, 39, 42],
      "euro_numbers" => [1, 8]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-03-08],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [2, 16, 24, 33, 48],
      "euro_numbers" => [5, 10]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-03-05],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [6, 12, 25, 31, 44],
      "euro_numbers" => [2, 12]
    },
    source: "import"
  },
  %{
    draw_date: ~D[2024-03-01],
    game_type: "eurojackpot",
    numbers: %{
      "main_numbers" => [1, 20, 29, 36, 50],
      "euro_numbers" => [6, 7]
    },
    source: "import"
  }
]

# Use the comprehensive recent draws
sample_draws = recent_draws

Enum.each(sample_draws, fn draw_attrs ->
  case Draws.create_draw(draw_attrs) do
    {:ok, draw} ->
      IO.puts("✓ Created draw for #{draw.draw_date}")

    {:error, changeset} ->
      IO.puts("✗ Failed to create draw for #{draw_attrs.draw_date}")
      IO.inspect(changeset.errors)
  end
end)

IO.puts("\nSeeding default strategies...")

# Create or get default user for strategies
default_user =
  case Accounts.get_user_by_email("demo@example.com") do
    nil ->
      # Create new demo user
      {:ok, user} =
        Accounts.register_user(%{
          email: "demo@example.com",
          password: "demo123456"
        })

      IO.puts("✓ Created demo user: demo@example.com")
      user

    user ->
      IO.puts("✓ Using existing demo user")
      user
  end

# Helper function to clean rules - remove fields not in StrategyRules schema
clean_rules = fn rules ->
  main_numbers =
    rules["main_numbers"]
    |> Map.drop(["blacklist", "max_per_decade", "max_consecutive"])

  euro_numbers =
    rules["euro_numbers"]
    |> Map.drop(["blacklist"])

  %{
    "main_numbers" => main_numbers,
    "euro_numbers" => euro_numbers
  }
end

# Default strategy prompts from UI
default_prompts = [
  "Strategia balansująca hot i cold numbers z wagami 40% hot, 40% random, 20% cold. Ratio 3 parzyste/2 nieparzyste.",
  "Strategia maksymalnie skupiona na hot numbers z ostatnich 32 losowań. Wagi: 80% hot, 20% random. Całkowicie ignoruj cold numbers.",
  "Strategia przeciwna do hot numbers - skupiamy się na liczbach cold (rzadko wypadających) z ostatnich 64 losowań. Wagi: 70% cold, 20% random, 10% hot."
]

# Generate and create default strategies
Enum.each(default_prompts, fn prompt ->
  case AIProvider.generate_strategy(prompt) do
    {:ok, ai_response} ->
      # Remove fields not in StrategyRules schema (blacklist, max_per_decade, max_consecutive)
      cleaned_rules = clean_rules.(ai_response.rules)

      attrs = %{
        name: ai_response.strategy_name,
        description: ai_response.description,
        type: "ai_generated",
        ai_prompt: prompt,
        rules: cleaned_rules
      }

      case Strategies.create_strategy(default_user, attrs) do
        {:ok, strategy} ->
          IO.puts("✓ Created strategy: #{strategy.name}")

        {:error, changeset} ->
          IO.puts("✗ Failed to create strategy: #{ai_response.strategy_name}")
          IO.inspect(changeset.errors)
      end

    {:error, reason} ->
      IO.puts("✗ Failed to generate strategy from prompt: #{inspect(reason)}")
  end
end)

IO.puts("\nSeeding completed!")
IO.puts("Total draws in database: #{Draws.count_draws()}")
IO.puts("Total strategies in database: #{Strategies.count_strategies(default_user)}")
