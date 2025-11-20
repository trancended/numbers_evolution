defmodule NumbersEvolution.Strategies.OpenRouterService do
  @moduledoc """
  OpenRouter service for AI-powered lottery strategy generation.

  This service implements the NumbersEvolution.AIProvider behaviour and provides
  high-level strategy generation using OpenRouter AI. It handles business logic
  including rate limiting, input validation, response processing, and error handling.

  Uses NumbersEvolution.Client.OpenRouterClient for low-level HTTP communication.
  """

  require Logger

  @behaviour NumbersEvolution.AIProvider

  alias NumbersEvolution.Client.OpenRouterClient

  # Rate limiting constants
  @max_generations_per_day 5
  # 24 hours
  @rate_limit_window_ms 86_400_000

  # API constants
  @default_system_message """
  You are an expert Eurojackpot strategy generator. Based on user input, create an innovative lottery strategy.

  You MUST respond with ONLY valid JSON matching this exact schema:
  {
    "name": "Strategy Name (max 100 chars)",
    "type": "ai_generated",
    "rules": {
      "main_numbers": {
        "ratio_even_odd": [even_count, odd_count],
        "ratio_low_high": [low_count, high_count],
        "preferred_hot": [array_of_hot_numbers],
        "preferred_cold": [array_of_cold_numbers],
        "weights": {"hot": 0.0-1.0, "cold": 0.0-1.0, "random": 0.0-1.0},
        "max_per_decade": 1-5,
        "max_consecutive": 1-5,
        "blacklist": []
      },
      "euro_numbers": {
        "ratio_even_odd": [even_count, odd_count],
        "preferred": [array_of_preferred_numbers],
        "weights": {"hot": 0.0-1.0, "random": 0.0-1.0},
        "blacklist": []
      }
    }
  }

  Guidelines:
  - Weights must sum to exactly 1.0
  - ratio_even_odd: [even, odd] where even + odd = 5 for main, = 2 for euro
  - ratio_low_high: [low, high] where low + high = 5, low = 1-25, high = 26-50
  - max_per_decade: max numbers from one decade (1-10,11-20,etc.)
  - max_consecutive: max consecutive numbers allowed
  - preferred_hot/cold: specific numbers to favor/avoid (max 10 numbers each)
  - Do not include any other text or explanation.
  """

  @response_schema %{
    "type" => "object",
    "additionalProperties" => false,
    "properties" => %{
      "name" => %{"type" => "string", "maxLength" => 100},
      "type" => %{"type" => "string", "enum" => ["ai_generated"]},
      "rules" => %{
        "type" => "object",
        "additionalProperties" => false,
        "properties" => %{
          "main_numbers" => %{
            "type" => "object",
            "additionalProperties" => false,
            "properties" => %{
              "ratio_even_odd" => %{
                "type" => "array",
                "items" => %{"type" => "integer", "minimum" => 0, "maximum" => 5},
                "minItems" => 2,
                "maxItems" => 2
              },
              "ratio_low_high" => %{
                "type" => "array",
                "items" => %{"type" => "integer", "minimum" => 0, "maximum" => 5},
                "minItems" => 2,
                "maxItems" => 2
              },
              "preferred_hot" => %{
                "type" => "array",
                "items" => %{"type" => "integer", "minimum" => 1, "maximum" => 50},
                "maxItems" => 10
              },
              "preferred_cold" => %{
                "type" => "array",
                "items" => %{"type" => "integer", "minimum" => 1, "maximum" => 50},
                "maxItems" => 10
              },
              "weights" => %{
                "type" => "object",
                "additionalProperties" => false,
                "properties" => %{
                  "hot" => %{"type" => "number", "minimum" => 0.0, "maximum" => 1.0},
                  "cold" => %{"type" => "number", "minimum" => 0.0, "maximum" => 1.0},
                  "random" => %{"type" => "number", "minimum" => 0.0, "maximum" => 1.0}
                },
                "required" => ["hot", "cold", "random"]
              },
              "max_per_decade" => %{"type" => "integer", "minimum" => 1, "maximum" => 5},
              "max_consecutive" => %{"type" => "integer", "minimum" => 1, "maximum" => 5},
              "blacklist" => %{
                "type" => "array",
                "items" => %{"type" => "integer", "minimum" => 1, "maximum" => 50}
              }
            },
            "required" => [
              "ratio_even_odd",
              "ratio_low_high",
              "preferred_hot",
              "preferred_cold",
              "weights",
              "max_per_decade",
              "max_consecutive",
              "blacklist"
            ]
          },
          "euro_numbers" => %{
            "type" => "object",
            "additionalProperties" => false,
            "properties" => %{
              "ratio_even_odd" => %{
                "type" => "array",
                "items" => %{"type" => "integer", "minimum" => 0, "maximum" => 2},
                "minItems" => 2,
                "maxItems" => 2
              },
              "preferred" => %{
                "type" => "array",
                "items" => %{"type" => "integer", "minimum" => 1, "maximum" => 12},
                "maxItems" => 5
              },
              "weights" => %{
                "type" => "object",
                "additionalProperties" => false,
                "properties" => %{
                  "hot" => %{"type" => "number", "minimum" => 0.0, "maximum" => 1.0},
                  "random" => %{"type" => "number", "minimum" => 0.0, "maximum" => 1.0}
                },
                "required" => ["hot", "random"]
              },
              "blacklist" => %{
                "type" => "array",
                "items" => %{"type" => "integer", "minimum" => 1, "maximum" => 12}
              }
            },
            "required" => ["ratio_even_odd", "preferred", "weights", "blacklist"]
          }
        },
        "required" => ["main_numbers", "euro_numbers"]
      }
    },
    "required" => ["name", "type", "rules"]
  }

  @doc """
  Generates a strategy based on a text prompt using OpenRouter AI.

  ## Parameters
  - `prompt`: String user prompt (10-500 characters)

  ## Returns
  - `{:ok, strategy_response}` - Successfully generated strategy
  - `{:error, :rate_limit_exceeded}` - User exceeded daily limit
  - `{:error, :prompt_too_short | :prompt_too_long | :invalid_content}` - Invalid prompt
  - `{:error, :api_error}` - AI service unavailable
  - `{:error, :invalid_response}` - AI returned invalid response
  """
  @impl true
  @spec generate_strategy(String.t()) ::
          {:ok, NumbersEvolution.AIProvider.strategy_response()} | {:error, atom()}
  def generate_strategy(prompt) do
    with :ok <- validate_prompt(prompt),
         :ok <- OpenRouterClient.validate_config(),
         {:ok, request_payload} <- build_request_payload(prompt),
         {:ok, response} <- OpenRouterClient.chat_completion(request_payload),
         {:ok, strategy_attrs} <- parse_response(response) do
      {:ok,
       %{
         strategy_name: strategy_attrs["name"],
         description: "AI-generated strategy based on: #{String.slice(prompt, 0, 100)}",
         reasoning: "Generated by AI based on user prompt",
         rules: strategy_attrs["rules"]
       }}
    else
      {:error, :api_key_missing} ->
        # Fallback to mock when API key is missing
        Logger.info("OpenRouter API key missing, falling back to mock implementation")
        NumbersEvolution.AIProvider.Mock.generate_strategy(prompt)

      {:error, reason} ->
        Logger.warning("OpenRouter strategy generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    exception ->
      Logger.error("OpenRouter unexpected error: #{inspect(exception)}")
      {:error, :generation_failed}
  end

  @doc """
  Validates a user prompt for strategy generation.

  ## Parameters
  - `prompt`: String to validate

  ## Returns
  - `:ok` - Prompt is valid
  - `{:error, :prompt_too_short}` - Prompt shorter than 10 characters
  - `{:error, :prompt_too_long}` - Prompt longer than 500 characters
  - `{:error, :invalid_content}` - Prompt contains forbidden content
  """
  @spec validate_prompt(String.t()) :: :ok | {:error, atom()}
  def validate_prompt(prompt) when is_binary(prompt) do
    cond do
      String.length(prompt) < 10 ->
        {:error, :prompt_too_short}

      String.length(prompt) > 500 ->
        {:error, :prompt_too_long}

      contains_forbidden_content?(prompt) ->
        {:error, :invalid_content}

      true ->
        :ok
    end
  end

  def validate_prompt(_), do: {:error, :invalid_prompt}

  @doc """
  Generates a detailed prompt based on strategy name.

  ## Parameters
  - `strategy_name`: Simple strategy identifier

  ## Returns
  - `String` - Full detailed prompt for AI
  """
  @spec build_strategy_prompt(String.t()) :: String.t()
  def build_strategy_prompt(strategy_name) do
    case strategy_name do
      "tylko_nieparzyste" ->
        "Utwórz strategię eurojackpot która całkowicie pomija wszystkie parzyste liczby główne (2,4,6,8,...50). Skup się wyłącznie na 25 nieparzystych liczbach (1,3,5,...49). Dla euro wszystkich liczb używaj normalnie. Strategia powinna mieć: ratio parzystych/nieparzystych 0:5 dla głównych, niskie/wysokie 3:2, maksymalnie 5 liczb z dekady, bez limitu kolejnych, wagi 50% hot i 50% random, preferuj gorące liczby."

      "dwie_nieparzyste_trzy_parzyste" ->
        "Utwórz strategię eurojackpot z precyzyjnym ratio parzystości: dokładnie 2 nieparzyste i 3 parzyste liczby główne. Dla euro zachowaj balans 1:1. Strategia powinna zawierać: ratio parzystych/nieparzystych 3:2 dla głównych i 1:1 dla euro, niskie/wysokie 2:3, maksymalnie 5 liczb z dekady, bez limitu kolejnych, wagi 50% hot, 20% cold, 30% random, preferuj gorące liczby 7,15,23,34,42."

      "max_dwie_w_dziesiatce" ->
        "Utwórz strategię eurojackpot z ograniczeniami dystrybucyjnymi: maksymalnie 2 liczby w jednej dziesiątce (np. 1-10,11-20,etc.) i całkowity zakaz kolejnych liczb (np. nie 7,8). Skup się na gorących liczbach z ostatnich losowań. Strategia powinna mieć: ratio parzystych/nieparzystych 2:3, niskie/wysokie 3:2, maksymalnie 2 liczby z dekady, maksymalnie 1 kolejna liczba, wagi 60% hot, 20% cold, 20% random, preferuj gorące liczby 7,15,23,34,42."

      "balans_hot_cold" ->
        "Utwórz zrównoważoną strategię eurojackpot balansującą trendy i losowość. Połącz gorące i zimne liczby w proporcjach 40% hot, 20% cold, 40% random. Strategia powinna zawierać: ratio parzystych/nieparzystych 3:2 dla głównych i 1:1 dla euro, niskie/wysokie 3:2, maksymalnie 5 liczb z dekady, bez limitu kolejnych, preferuj gorące 7,23,34 i zimne 1,50, maksymalnie 10 preferowanych liczb każdego typu."

      "ekstremalna_hot" ->
        "Utwórz ekstremalną strategię eurojackpot skupiającą się maksymalnie na gorących liczbach z ostatnich 32 losowań. Całkowicie ignoruj zimne liczby. Strategia powinna mieć: ratio parzystych/nieparzystych 2:3, niskie/wysokie 2:3, maksymalnie 5 liczb z dekady, maksymalnie 3 kolejne liczby, wagi 80% hot, 0% cold, 20% random, preferuj 9 gorących liczb jak 7,12,18,23,28,34,39,42,47."

      "przeciwny_trend" ->
        "Utwórz strategię eurojackpot działającą odwrotnie do popularnych trendów - skup się na cold numbers (rzadko wypadających liczbach) z ostatnich 64 losowań. Strategia powinna zawierać: ratio parzystych/nieparzystych 2:3, niskie/wysokie 3:2, maksymalnie 5 liczb z dekady, bez limitu kolejnych, wagi 10% hot, 70% cold, 20% random, preferuj 9 zimnych liczb jak 1,5,13,17,25,31,41,45,50."

      _ ->
        "Utwórz zrównoważoną strategię eurojackpot balansującą gorące i losowe liczby w proporcjach około 40% hot i 60% random. Strategia powinna mieć odpowiednie proporcje parzystych/nieparzystych oraz niskich/wysokich liczb."
    end
  end

  @doc """
  Checks if user has exceeded rate limit for AI generation.

  ## Parameters
  - `user_id`: User identifier

  ## Returns
  - `:ok` - User can generate
  - `{:error, :rate_limit_exceeded}` - User exceeded limit
  """
  @spec check_rate_limit(binary()) :: :ok | {:error, :rate_limit_exceeded}
  def check_rate_limit(user_id) do
    table = get_rate_limit_table()
    now = System.system_time(:millisecond)

    case :ets.lookup(table, user_id) do
      [{^user_id, count, window_start}] when now - window_start < @rate_limit_window_ms ->
        if count >= @max_generations_per_day do
          {:error, :rate_limit_exceeded}
        else
          :ok
        end

      _ ->
        # New window or no record
        :ok
    end
  end

  @doc """
  Increments the rate limit counter for a user.
  Should be called after successful generation.
  """
  @spec increment_rate_limit(binary()) :: :ok
  def increment_rate_limit(user_id) do
    table = get_rate_limit_table()
    now = System.system_time(:millisecond)

    case :ets.lookup(table, user_id) do
      [{^user_id, count, window_start}] when now - window_start < @rate_limit_window_ms ->
        :ets.insert(table, {user_id, count + 1, window_start})

      _ ->
        # New window
        :ets.insert(table, {user_id, 1, now})
    end

    :ok
  end

  # Private methods

  defp build_request_payload(prompt, opts \\ []) do
    config = Application.get_env(:numbers_evolution, :openrouter, %{})
    model = Keyword.get(opts, :model, config[:default_model] || "openai/gpt-4o-mini")

    payload = %{
      model: model,
      messages: [
        %{role: "system", content: @default_system_message},
        %{role: "user", content: sanitize_prompt(prompt)}
      ],
      response_format: %{
        type: "json_schema",
        json_schema: %{
          name: "lotto_strategy",
          strict: true,
          schema: @response_schema
        }
      },
      temperature: 0.7,
      max_tokens: 1000
    }

    {:ok, payload}
  end

  defp parse_response(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    with {:ok, parsed} <- Jason.decode(content),
         :ok <- validate_response_schema(parsed) do
      {:ok, parsed}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, :invalid_json_response}

      {:error, :invalid_schema} ->
        {:error, :invalid_response_schema}
    end
  end

  defp parse_response(_), do: {:error, :invalid_response_format}

  defp validate_response_schema(data) do
    # Basic validation - in production, consider using ExJsonSchema
    with {:ok, _} <- validate_basic_structure(data),
         :ok <- validate_main_numbers(data),
         :ok <- validate_euro_numbers(data) do
      :ok
    else
      _ -> {:error, :invalid_schema}
    end
  end

  defp validate_basic_structure(data) do
    required_keys = ["name", "type", "rules"]
    has_required = Enum.all?(required_keys, &Map.has_key?(data, &1))

    if has_required and data["type"] == "ai_generated" and is_map(data["rules"]) do
      {:ok, data}
    else
      :error
    end
  end

  defp validate_main_numbers(%{"rules" => %{"main_numbers" => main}}) do
    # Validate ratio_even_odd sums to 5
    with [even, odd] when even + odd == 5 <- main["ratio_even_odd"],
         [low, high] when low + high == 5 <- main["ratio_low_high"],
         %{"hot" => hot, "cold" => cold, "random" => random} <- main["weights"],
         sum when sum >= 0.99 and sum <= 1.01 <- hot + cold + random,
         max_decade when max_decade in 1..5 <- main["max_per_decade"],
         max_consec when max_consec in 1..5 <- main["max_consecutive"],
         true <- is_list(main["preferred_hot"]) and is_list(main["preferred_cold"]),
         true <- is_list(main["blacklist"]) do
      :ok
    else
      _ -> :error
    end
  end

  defp validate_euro_numbers(%{"rules" => %{"euro_numbers" => euro}}) do
    # Validate ratio_even_odd sums to 2
    with [even, odd] when even + odd == 2 <- euro["ratio_even_odd"],
         %{"hot" => hot, "random" => random} <- euro["weights"],
         sum when sum >= 0.99 and sum <= 1.01 <- hot + random,
         true <- is_list(euro["preferred"]),
         true <- is_list(euro["blacklist"]) do
      :ok
    else
      _ -> :error
    end
  end

  defp sanitize_prompt(prompt) do
    prompt
    |> String.trim()
    |> String.slice(0, 500)
    |> remove_forbidden_patterns()
  end

  defp contains_forbidden_content?(prompt) do
    forbidden_patterns = [
      ~r/(?i)ignore.*previous/i,
      ~r/(?i)system.*prompt/i,
      ~r/(?i)reveal.*prompt/i,
      ~r/(?i)internal.*instruction/i
    ]

    Enum.any?(forbidden_patterns, &Regex.match?(&1, prompt))
  end

  defp remove_forbidden_patterns(prompt) do
    forbidden_patterns = [
      ~r/(?i)ignore.*previous/i,
      ~r/(?i)system.*prompt/i,
      ~r/(?i)reveal.*prompt/i,
      ~r/(?i)internal.*instruction/i
    ]

    Enum.reduce(forbidden_patterns, prompt, fn pattern, acc ->
      Regex.replace(pattern, acc, "")
    end)
  end

  defp get_rate_limit_table do
    case :ets.whereis(:openrouter_rate_limits) do
      :undefined ->
        :ets.new(:openrouter_rate_limits, [:set, :public, :named_table])
        :openrouter_rate_limits

      table ->
        table
    end
  end
end
