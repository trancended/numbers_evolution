defmodule NumbersEvolution.AIProvider.Mock do
  @moduledoc """
  Mock AI provider for strategy generation.

  Maps common prompts to predefined strategies for testing/demo purposes.
  This can be replaced with real AI API integration (Claude, GPT, etc.)
  """

  @behaviour NumbersEvolution.AIProvider

  @impl true
  def generate_strategy(prompt) when is_binary(prompt) do
    normalized_prompt = String.downcase(prompt)

    matchers = [
      # Order matters - more specific matches first
      &match_ekstremalna_hot/1,
      &match_przeciwny_trend/1,
      &match_balans_hot_cold/1,
      &match_complex_skip_half_max2_decade_3odd_2even/1,
      &match_tylko_nieparzyste/1,
      &match_2_nieparzyste_3_parzyste/1,
      &match_max_2_w_dziesiatce/1,
      &match_pelna_losowosc/1
    ]

    strategy =
      Enum.find_value(matchers, fn matcher ->
        matcher.(normalized_prompt)
      end) || strategy_balans_hot_cold()

    {:ok, strategy}
  rescue
    _ -> {:error, :generation_failed}
  end

  # Matcher functions - each returns strategy map or nil

  defp match_tylko_nieparzyste(normalized_prompt) do
    # Match prompts that want ONLY odd numbers, not complex combinations
    # Must contain "tylko" or "same" and "nieparzyste", but no other constraints
    has_only_modifier =
      String.contains?(normalized_prompt, "tylko") or
        String.contains?(normalized_prompt, "same") or
        String.contains?(normalized_prompt, "wyłącznie")

    has_constraints =
      String.contains?(normalized_prompt, "max ") or
        String.contains?(normalized_prompt, "dziesiąt") or
        String.contains?(normalized_prompt, "połow") or
        String.contains?(normalized_prompt, "3 ") or
        String.contains?(normalized_prompt, "dwie")

    if has_only_modifier and String.contains?(normalized_prompt, "nieparzyste") and
         not has_constraints do
      strategy_tylko_nieparzyste()
    end
  end

  defp match_2_nieparzyste_3_parzyste(normalized_prompt) do
    if String.contains?(normalized_prompt, "dwie") and
         String.contains?(normalized_prompt, "nieparzyste") and
         String.contains?(normalized_prompt, "parzyste") do
      strategy_2_nieparzyste_3_parzyste()
    end
  end

  defp match_max_2_w_dziesiatce(normalized_prompt) do
    if String.contains?(normalized_prompt, "dziesiąt") and
         (String.contains?(normalized_prompt, "max") or
            String.contains?(normalized_prompt, "kolejn")) do
      strategy_max_2_w_dziesiatce()
    end
  end

  defp match_balans_hot_cold(normalized_prompt) do
    if String.contains?(normalized_prompt, "balans") and
         (String.contains?(normalized_prompt, "hot") or
            String.contains?(normalized_prompt, "cold")) and
         (String.contains?(normalized_prompt, "40%") or
            String.contains?(normalized_prompt, "40 %")) do
      strategy_balans_hot_cold()
    end
  end

  defp match_ekstremalna_hot(normalized_prompt) do
    if (String.contains?(normalized_prompt, "ekstrem") or
          String.contains?(normalized_prompt, "maksym")) and
         String.contains?(normalized_prompt, "hot") and
         (String.contains?(normalized_prompt, "80%") or
            String.contains?(normalized_prompt, "80 %")) do
      strategy_ekstremalna_hot()
    end
  end

  defp match_przeciwny_trend(normalized_prompt) do
    if String.contains?(normalized_prompt, "cold") and
         (String.contains?(normalized_prompt, "przeciw") or
            String.contains?(normalized_prompt, "rzadko")) and
         (String.contains?(normalized_prompt, "70%") or
            String.contains?(normalized_prompt, "70 %")) do
      strategy_przeciwny_trend()
    end
  end

  defp match_pelna_losowosc(normalized_prompt) do
    if String.contains?(normalized_prompt, "losow") do
      strategy_pelna_losowosc()
    end
  end

  defp match_complex_skip_half_max2_decade_3odd_2even(normalized_prompt) do
    if String.contains?(normalized_prompt, "pomin") and
         String.contains?(normalized_prompt, "połow") and
         (String.contains?(normalized_prompt, "max 2") or
            String.contains?(normalized_prompt, "dziesiąt")) and
         String.contains?(normalized_prompt, "3") and
         String.contains?(normalized_prompt, "nieparzyste") and
         String.contains?(normalized_prompt, "dwie") and
         String.contains?(normalized_prompt, "parzyste") do
      strategy_complex_skip_half_max2_decade_3odd_2even()
    end
  end

  # Strategia 1: Tylko Nieparzyste
  defp strategy_tylko_nieparzyste do
    %{
      strategy_name: "Tylko Nieparzyste",
      description:
        "Strategia pomijająca wszystkie parzyste liczby główne (1-50). Skupia się wyłącznie na 25 nieparzystych liczbach.",
      reasoning:
        "Strategia redukuje pulę liczb do połowy, koncentrując się tylko na nieparzystych. Równe wagi hot i random (50/50) zapewniają balans między trendami a losowością.",
      rules: %{
        "main_numbers" => %{
          "blacklist" => [
            2,
            4,
            6,
            8,
            10,
            12,
            14,
            16,
            18,
            20,
            22,
            24,
            26,
            28,
            30,
            32,
            34,
            36,
            38,
            40,
            42,
            44,
            46,
            48,
            50
          ],
          "ratio_even_odd" => [0, 5],
          "ratio_low_high" => [3, 2],
          "preferred_hot" => [],
          "preferred_cold" => [],
          "weights" => %{"hot" => 0.5, "cold" => 0.0, "random" => 0.5},
          "max_per_decade" => 5,
          "max_consecutive" => 5
        },
        "euro_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [1, 1],
          "preferred" => [],
          "weights" => %{"hot" => 0.5, "random" => 0.5}
        }
      }
    }
  end

  # Strategia 2: 2 Nieparzyste, 3 Parzyste
  defp strategy_2_nieparzyste_3_parzyste do
    %{
      strategy_name: "2 Nieparzyste, 3 Parzyste",
      description:
        "Precyzyjne określenie ratio parzystości - dokładnie 2 nieparzyste i 3 parzyste liczby.",
      reasoning:
        "Strategia korzysta z pełnej puli liczb (50) z określonym ratio. Wagi 50% hot, 20% cold, 30% random zapewniają przewagę gorących liczb przy zachowaniu różnorodności.",
      rules: %{
        "main_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [3, 2],
          "ratio_low_high" => [2, 3],
          "preferred_hot" => [],
          "preferred_cold" => [],
          "weights" => %{"hot" => 0.5, "cold" => 0.2, "random" => 0.3},
          "max_per_decade" => 5,
          "max_consecutive" => 5
        },
        "euro_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [1, 1],
          "preferred" => [],
          "weights" => %{"hot" => 0.5, "random" => 0.5}
        }
      }
    }
  end

  # Strategia 3: Max 2 w Dziesiątce
  defp strategy_max_2_w_dziesiatce do
    %{
      strategy_name: "Max 2 w Dziesiątce",
      description:
        "Strategia z ograniczeniami dystrybucji: maksymalnie 2 liczby w jednej dziesiątce i brak kolejnych liczb.",
      reasoning:
        "Ograniczenia dystrybucji (max 2 w dziesiątce, max 1 kolejna) tworzą bardziej rozproszone zestawy. Wysokie wagi na hot numbers (60%) preferują często wypadające liczby.",
      rules: %{
        "main_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [2, 3],
          "ratio_low_high" => [3, 2],
          "preferred_hot" => [7, 15, 23, 34, 42],
          "preferred_cold" => [],
          "weights" => %{"hot" => 0.6, "cold" => 0.2, "random" => 0.2},
          "max_per_decade" => 2,
          "max_consecutive" => 1
        },
        "euro_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [1, 1],
          "preferred" => [3, 9],
          "weights" => %{"hot" => 0.6, "random" => 0.4}
        }
      }
    }
  end

  # Strategia 4: Balans Hot/Cold
  defp strategy_balans_hot_cold do
    %{
      strategy_name: "Balans Hot/Cold",
      description:
        "Zbalansowane podejście z równymi wagami hot i random, oraz małą wagą cold numbers.",
      reasoning:
        "Strategia łączy trendy (hot) z losowością (random) i niewielkim udziałem cold numbers. Preferowane liczby hot (7, 23, 34) i cold (1, 50) zapewniają różnorodność.",
      rules: %{
        "main_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [3, 2],
          "ratio_low_high" => [3, 2],
          "preferred_hot" => [7, 23, 34],
          "preferred_cold" => [1, 50],
          "weights" => %{"hot" => 0.4, "cold" => 0.2, "random" => 0.4},
          "max_per_decade" => 5,
          "max_consecutive" => 5
        },
        "euro_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [1, 1],
          "preferred" => [3, 9],
          "weights" => %{"hot" => 0.5, "random" => 0.5}
        }
      }
    }
  end

  # Strategia 5: Ekstremalna Hot
  defp strategy_ekstremalna_hot do
    %{
      strategy_name: "Ekstremalna Hot",
      description:
        "Maksymalne skupienie na hot numbers z ostatnich losowań. Całkowicie ignoruje cold numbers.",
      reasoning:
        "Strategia ekstremalna: 80% hot, 0% cold, 20% random. Zakłada kontynuację trendów. 9 preferowanych hot numbers głównych i 5 euro zapewniają silną preferencję dla gorących liczb.",
      rules: %{
        "main_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [2, 3],
          "ratio_low_high" => [2, 3],
          "preferred_hot" => [7, 12, 18, 23, 28, 34, 39, 42, 47],
          "preferred_cold" => [],
          "weights" => %{"hot" => 0.8, "cold" => 0.0, "random" => 0.2},
          "max_per_decade" => 5,
          "max_consecutive" => 3
        },
        "euro_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [1, 1],
          "preferred" => [3, 5, 7, 9, 11],
          "weights" => %{"hot" => 0.9, "random" => 0.1}
        }
      }
    }
  end

  # Strategia 6: Przeciwny Trend
  defp strategy_przeciwny_trend do
    %{
      strategy_name: "Przeciwny Trend",
      description: "Gra przeciwko trendowi - skupienie na cold numbers (rzadko wypadających).",
      reasoning:
        "Odwrotna logika: 70% cold, tylko 10% hot. Zakłada że 'zaniedbane' liczby mają większą szansę na wylosowanie. 9 preferowanych cold numbers dla głównych.",
      rules: %{
        "main_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [2, 3],
          "ratio_low_high" => [3, 2],
          "preferred_hot" => [],
          "preferred_cold" => [1, 5, 13, 17, 25, 31, 41, 45, 50],
          "weights" => %{"hot" => 0.1, "cold" => 0.7, "random" => 0.2},
          "max_per_decade" => 5,
          "max_consecutive" => 5
        },
        "euro_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [1, 1],
          "preferred" => [1, 2, 12],
          "weights" => %{"hot" => 0.2, "random" => 0.8}
        }
      }
    }
  end

  # Strategia 7: Pełna Losowość
  defp strategy_pelna_losowosc do
    %{
      strategy_name: "Pełna Losowość",
      description: "Czysto losowa strategia bez preferencji - służy jako kontrola/baseline.",
      reasoning:
        "100% random dla wszystkich liczb. Brak preferowanych liczb i blacklist. Używana jako baseline do porównania skuteczności innych strategii.",
      rules: %{
        "main_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [2, 3],
          "ratio_low_high" => [2, 3],
          "preferred_hot" => [],
          "preferred_cold" => [],
          "weights" => %{"hot" => 0.0, "cold" => 0.0, "random" => 1.0},
          "max_per_decade" => 5,
          "max_consecutive" => 5
        },
        "euro_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [1, 1],
          "preferred" => [],
          "weights" => %{"hot" => 0.0, "random" => 1.0}
        }
      }
    }
  end

  # Strategia 8: Pomin Połowę + Max 2 w Dziesiątce + 3 Nieparzyste 2 Parzyste
  defp strategy_complex_skip_half_max2_decade_3odd_2even do
    %{
      strategy_name: "Pomin Połowę + Max 2 w Dziesiątce + 3 Nieparzyste 2 Parzyste",
      description:
        "Złożona strategia: pominięcie połowy losowych liczb, maksymalnie 2 liczby w jednej dziesiątce oraz dokładnie 3 nieparzyste i 2 parzyste liczby główne.",
      reasoning:
        "Strategia łączy ograniczenia dystrybucji (max 2 w dziesiątce) z precyzyjnym ratio parzystości (3 nieparzyste, 2 parzyste) i redukcją puli liczb poprzez wyższe wagi na hot numbers (50%) i niższe na random (30%).",
      rules: %{
        "main_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [2, 3],
          "ratio_low_high" => [3, 2],
          "preferred_hot" => [],
          "preferred_cold" => [],
          "weights" => %{"hot" => 0.5, "cold" => 0.2, "random" => 0.3},
          "max_per_decade" => 2,
          "max_consecutive" => 5
        },
        "euro_numbers" => %{
          "blacklist" => [],
          "ratio_even_odd" => [1, 1],
          "preferred" => [],
          "weights" => %{"hot" => 0.5, "random" => 0.5}
        }
      }
    }
  end
end
