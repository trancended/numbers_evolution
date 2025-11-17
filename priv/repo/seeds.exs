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

# Recent draws from latest Eurojackpot results (imported from official sources)
# Eurojackpot draws take place on Tuesdays and Fridays
recent_draws = [
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
  }
]

# Legacy sample draws (kept for backward compatibility)
sample_draws = [
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

# Combine recent imported draws with legacy sample draws
sample_draws = recent_draws ++ sample_draws

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
