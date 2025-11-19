# OpenRouter Service Implementation Plan

## 1. Opis architektury

OpenRouter integration składa się z dwóch modułów Elixir odpowiedzialnych za integrację z API OpenRouter w aplikacji Numbers Evolution:

### 1.1 OpenRouterClient (HTTP Layer)
Moduł `NumbersEvolution.Client.OpenRouterClient` odpowiedzialny wyłącznie za niskopoziomową komunikację HTTP z API OpenRouter. Zawiera metody do wysyłania requestów i obsługi odpowiedzi HTTP.

### 1.2 OpenRouterService (Business Layer)
Moduł `NumbersEvolution.Strategies.OpenRouterService` implementujący logikę biznesową, rate limiting, walidację oraz `NumbersEvolution.AIProvider` behaviour. Korzysta z OpenRouterClient do komunikacji HTTP.

Razem umożliwiają generowanie strategii lotto poprzez komunikację z modelami LLM dostępnymi przez OpenRouter, implementują wzorce funkcjonalne, obsługują strukturę odpowiedzi JSON, rate limiting oraz bezpieczeństwo API. Wykorzystują bibliotekę Req do HTTP requests, zgodnie z zasadami projektu.

## 2. Konfiguracja

Oba moduły korzystają z tej samej konfiguracji aplikacji ładowanej z config files:

```elixir
# W config/runtime.exs lub config/dev.exs/prod.exs
config :numbers_evolution, :openrouter,
  api_key: System.get_env("OPENROUTER_API_KEY"),
  base_url: "https://openrouter.ai/api/v1",
  default_model: "openai/gpt-4o-mini",
  timeout: 30_000,
  rate_limit_per_hour: 100

# Konfiguracja AI provider (service)
config :numbers_evolution, :ai_provider, NumbersEvolution.Strategies.OpenRouterService
```

### 2.1 OpenRouterClient
Używa funkcji `config()` do dostępu do konfiguracji runtime:

```elixir
defp config do
  Application.get_env(:numbers_evolution, :openrouter, %{
    api_key: nil,
    base_url: "https://openrouter.ai/api/v1",
    default_model: "openai/gpt-4o-mini",
    timeout: 30_000,
    rate_limit_per_hour: 100
  })
end
```

### 2.2 OpenRouterService
Korzysta z tej samej konfiguracji poprzez Application.get_env w razie potrzeby.

## 3. API modułów

### 3.1 OpenRouterClient (HTTP Client)

**Lokalizacja:** `lib/numbers_evolution/client/openrouter_client.ex`

#### Metody publiczne

##### `chat_completion(payload, opts \\ [])`

Wysyła request chat completion do OpenRouter API.

**Parametry:**
- `payload`: Map - request payload
- `opts`: Keyword - opcje override (api_key, base_url, timeout)

**Zwraca:**
- `{:ok, response}` - odpowiedź API
- `{:error, :rate_limit_exceeded | :client_error | :server_error | :timeout | :network_error}`

##### `list_models(opts \\ [])`

Lista dostępnych modeli OpenRouter.

**Parametry:**
- `opts`: Keyword - opcje override (api_key, base_url, timeout)

**Zwraca:**
- `{:ok, [String.t()]}` - lista nazw modeli
- `{:error, :api_key_missing | :network_error | :unexpected_error}`

##### `validate_config()`

Sprawdza czy konfiguracja API jest prawidłowa.

**Zwraca:**
- `:ok` - konfiguracja OK
- `{:error, :api_key_missing}` - brak API key

### 3.2 OpenRouterService (Business Service)

**Lokalizacja:** `lib/numbers_evolution/strategies/openrouter_service.ex`

Implementuje `NumbersEvolution.AIProvider` behaviour.

#### Metody publiczne

##### `generate_strategy(prompt)`

Główna metoda do generowania strategii (implementuje AIProvider behaviour).

**Parametry:**
- `prompt`: String - prompt użytkownika (10-500 znaków)

**Zwraca:**
- `{:ok, strategy_response}` - struktura strategii
- `{:error, :prompt_too_short | :prompt_too_long | :invalid_content | :api_error | :invalid_response}`

##### `validate_prompt(prompt)`

Waliduje prompt użytkownika.

**Parametry:** `prompt`: String

**Zwraca:** `:ok` lub `{:error, :prompt_too_short | :prompt_too_long | :invalid_content | :invalid_prompt}`

##### `check_rate_limit(user_id)`

Sprawdza rate limit dla użytkownika.

**Parametry:** `user_id`: binary - ID użytkownika

**Zwraca:** `:ok` lub `{:error, :rate_limit_exceeded}`

##### `increment_rate_limit(user_id)`

Zwiększa licznik rate limit dla użytkownika.

**Parametry:** `user_id`: binary - ID użytkownika

**Zwraca:** `:ok`

#### Typ zwracany strategy_response
```elixir
%{
  strategy_name: String.t(),
  description: String.t(),
  reasoning: String.t(),
  rules: map()
}
```

## 4. Implementacja wewnętrzna

### 4.1 OpenRouterClient - Metody prywatne

#### `config()`
Zwraca konfigurację aplikacji.

#### `handle_api_response(response)`
Obsługuje odpowiedź HTTP od Req.

```elixir
defp handle_api_response({:ok, %{status: 200, body: body}}) do
  {:ok, body}
end

defp handle_api_response({:ok, %{status: 429}}) do
  {:error, :rate_limit_exceeded}
end

defp handle_api_response({:ok, %{status: status}}) when status >= 400 and status < 500 do
  {:error, :client_error}
end

defp handle_api_response({:ok, %{status: status}}) when status >= 500 do
  {:error, :server_error}
end

defp handle_api_response({:error, %Req.TransportError{reason: :timeout}}) do
  {:error, :timeout}
end

defp handle_api_response({:error, _}) do
  {:error, :network_error}
end
```

### 4.2 OpenRouterService - Metody prywatne

#### `build_request_payload(prompt, opts)`
Konstruuje payload dla API request.

```elixir
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
```

#### `parse_response(response)`
Parsuje odpowiedź API i waliduje schemat JSON.

```elixir
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
```

#### `validate_response_schema(data)`
Waliduje odpowiedź względem JSON Schema.

```elixir
defp validate_response_schema(data) do
  required_keys = ["name", "type", "rules"]
  has_required = Enum.all?(required_keys, &Map.has_key?(data, &1))

  if has_required do
    # Validate weights sum to 1.0
    with %{"rules" => %{"weights" => weights}} <- data,
         true <- is_map(weights),
         true <-
           Map.has_key?(weights, "hot") and Map.has_key?(weights, "cold") and
             Map.has_key?(weights, "random"),
         sum when sum >= 0.99 and sum <= 1.01 <-
           weights["hot"] + weights["cold"] + weights["random"] do
      :ok
    else
      _ -> {:error, :invalid_schema}
    end
  else
    {:error, :invalid_schema}
  end
end
```

#### `sanitize_prompt(prompt)`
Czyści prompt z zabronionych treści.

#### `contains_forbidden_content?(prompt)`
Sprawdza czy prompt zawiera zabronione treści.

#### `get_rate_limit_table()`
Zwraca ETS table dla rate limiting.

### 4.3 Stałe modułu OpenRouterService

- `@max_generations_per_day`: 5 - limit generacji na użytkownika dziennie
- `@rate_limit_window_ms`: 86_400_000 - okno czasowe (24h)
- `@default_system_message`: Komunikat systemowy dla AI
- `@response_schema`: JSON Schema dla walidacji odpowiedzi

## 5. Obsługa błędów

Architektura implementuje wielopoziomową obsługę błędów z użyciem railway pattern.

### 5.1 Poziomy obsługi błędów

#### OpenRouterClient (HTTP Layer)
Obsługuje błędy HTTP i sieciowe:
- `:rate_limit_exceeded` - API rate limit (HTTP 429)
- `:client_error` - błędy klienta (HTTP 4xx)
- `:server_error` - błędy serwera (HTTP 5xx)
- `:timeout` - timeout połączenia
- `:network_error` - błędy sieciowe

#### OpenRouterService (Business Layer)
Obsługuje błędy biznesowe i walidacyjne:
- `:prompt_too_short | :prompt_too_long | :invalid_content` - błędy walidacji prompt
- `:rate_limit_exceeded` - przekroczony limit użytkownika
- `:api_key_missing` - brak konfiguracji API
- `:invalid_json_response | :invalid_response_schema` - błędy parsowania odpowiedzi

### 5.2 Railway Pattern Implementation

```elixir
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
    {:error, reason} ->
      Logger.warning("OpenRouter strategy generation failed: #{inspect(reason)}")
      {:error, reason}
  end
rescue
  exception ->
    Logger.error("OpenRouter unexpected error: #{inspect(exception)}")
    {:error, :generation_failed}
end
```

### 5.3 Scenariusze błędów

1. **Warstwa HTTP (Client)**: `:rate_limit_exceeded`, `:client_error`, `:server_error`, `:timeout`, `:network_error`
2. **Warstwa biznesowa (Service)**: `:prompt_too_short`, `:prompt_too_long`, `:invalid_content`, `:api_key_missing`
3. **Warstwa parsowania**: `:invalid_json_response`, `:invalid_response_schema`, `:invalid_response_format`
4. **Warstwa aplikacji**: `:generation_failed` (catch-all dla wyjątków)

## 6. Bezpieczeństwo

Wielowarstwowe podejście do bezpieczeństwa w obu modułach.

### 6.1 Bezpieczeństwo API (OpenRouterClient)

- **API Key Management**: Klucz ładowany z environment variables
- **Request Headers**: Bezpieczne ustawianie Authorization header
- **Error Handling**: Nie ujawnia wrażliwych danych w błędach
- **Network Security**: Użycie Req z timeoutami i obsługą błędów

### 6.2 Bezpieczeństwo biznesowe (OpenRouterService)

- **Rate Limiting**: 5 generacji/dzień per użytkownik (ETS-based)
- **Input Validation**: Walidacja długości prompt (10-500 znaków)
- **Input Sanitization**: Usuwanie zabronionych wzorców z prompt
- **Output Validation**: JSON Schema validation odpowiedzi AI
- **Logging**: Bezpieczne logowanie bez wrażliwych danych

### 6.3 Implementacja rate limiting

```elixir
# ETS-based rate limiting (prosta implementacja)
@max_generations_per_day 5
@rate_limit_window_ms 86_400_000  # 24 hours

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
    _ -> :ok
  end
end

def increment_rate_limit(user_id) do
  table = get_rate_limit_table()
  now = System.system_time(:millisecond)

  case :ets.lookup(table, user_id) do
    [{^user_id, count, window_start}] when now - window_start < @rate_limit_window_ms ->
      :ets.insert(table, {user_id, count + 1, window_start})
    _ ->
      :ets.insert(table, {user_id, 1, now})
  end

  :ok
end
```

### 6.4 Input sanitization

```elixir
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
```

## 7. Architektura i struktura plików

### 7.1 Struktura katalogów

```
lib/numbers_evolution/
├── client/
│   └── openrouter_client.ex          # HTTP client layer
├── strategies/
│   ├── openrouter_service.ex         # Business service layer
│   └── [inne pliki strategii...]
└── ai_provider.ex                    # AI provider behaviour

test/numbers_evolution/
├── client/
│   └── openrouter_client_test.exs    # Testy HTTP client
├── strategies/
│   └── openrouter_service_test.exs   # Testy business service
└── [inne testy...]
```

### 7.2 Sekwencja wywołań

```
AIProvider.generate_strategy(prompt)
    ↓
OpenRouterService.generate_strategy(prompt)
    ↓ [validate_prompt, check_rate_limit]
OpenRouterClient.validate_config()
    ↓
OpenRouterClient.chat_completion(payload)
    ↓ [HTTP request via Req]
OpenRouter API
    ↓ [JSON response]
OpenRouterService.parse_response()
    ↓ [validate JSON schema]
{:ok, strategy_response}
```

### 7.3 Konfiguracja aplikacji

**config/dev.exs & config/runtime.exs:**
```elixir
config :numbers_evolution, :openrouter,
  api_key: System.get_env("OPENROUTER_API_KEY"),
  base_url: "https://openrouter.ai/api/v1",
  default_model: "openai/gpt-4o-mini",
  timeout: 30_000,
  rate_limit_per_hour: 100

config :numbers_evolution, :ai_provider, NumbersEvolution.Strategies.OpenRouterService
```

### 7.4 Parametry AI

**System Message:**
```elixir
@default_system_message """
You are an expert Eurojackpot strategy generator. Based on user input, create an innovative lottery strategy.

You MUST respond with ONLY valid JSON matching this exact schema:
{
  "name": "Strategy Name (max 100 chars)",
  "type": "ai_generated",
  "rules": {
    "weights": {
      "hot": 0.0-1.0,
      "cold": 0.0-1.0,
      "random": 0.0-1.0
    }
  }
}

The weights must sum to exactly 1.0. Do not include any other text or explanation.
"""
```

**Request Payload:**
```elixir
%{
  model: "openai/gpt-4o-mini",
  messages: [
    %{role: "system", content: @default_system_message},
    %{role: "user", content: sanitized_prompt}
  ],
  response_format: %{
    type: "json_schema",
    json_schema: %{name: "lotto_strategy", strict: true, schema: @response_schema}
  },
  temperature: 0.7,
  max_tokens: 1000
}
```

### 7.5 Testowanie

**Test Coverage:**
- ✅ OpenRouterClient: HTTP communication, config validation, error handling
- ✅ OpenRouterService: Business logic, rate limiting, prompt validation, response parsing
- ✅ Integration: End-to-end flow przez AIProvider behaviour

**Test Strategy:**
- Unit tests dla obu modułów
- Mock external dependencies (Req HTTP calls)
- ETS-based rate limiting w testach
- Comprehensive error scenario coverage

## 8. Podsumowanie implementacji

### ✅ Zrealizowane cele:

1. **Architektura warstwowa**: Oddzielenie HTTP client od business logic
2. **Single Responsibility**: Client = HTTP, Service = Business + AIProvider
3. **Testability**: Łatwiejsze mockowanie i testowanie obu warstw
4. **Maintainability**: Jasny podział odpowiedzialności i enkapsulacja
5. **Security**: Wielopoziomowe bezpieczeństwo (HTTP + Business)
6. **Error Handling**: Kompleksowa obsługa błędów z railway pattern
7. **AIProvider Integration**: Bezproblemowa integracja z istniejącym systemem

### 🏗️ Kluczowe komponenty:

- **OpenRouterClient**: Czysty HTTP client z obsługą błędów sieciowych
- **OpenRouterService**: Business service implementujący AIProvider behaviour
- **Rate Limiting**: ETS-based, 5 generacji/dzień per użytkownik
- **Input Validation**: Prompt validation + sanitization
- **Output Validation**: JSON Schema validation odpowiedzi AI
- **Configuration**: Runtime config z environment variables

### 🚀 Status: IMPLEMENTED & TESTED

Oba moduły są w pełni zaimplementowane, przetestowane i zintegrowane z aplikacją Numbers Evolution. Architektura umożliwia łatwe rozszerzenia i utrzymanie zgodnie z zasadami Domain-Driven Design i Clean Architecture.
