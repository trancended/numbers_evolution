# REST API Implementation Plan - Numbers Evolution

**Version:** 1.0  
**Date:** November 15, 2025  
**Framework:** Phoenix/Elixir  
**Target MVP:** Week 1-6

---

## Analysis Summary

<analysis>

### 1. Key API Specification Points

The Numbers Evolution REST API consists of 6 main resource groups:

1. **Users** - Authentication, registration, preferences (4 endpoints)
2. **Strategies** - CRUD, AI generation, mixing (6 endpoints)  
3. **Draws** - Historical lottery data, analysis (4 endpoints)
4. **Simulations** - Running simulations, progress tracking (5 endpoints)
5. **Rankings** - Strategy performance rankings (2 endpoints)
6. **Coupons** - Number generation (2 endpoints)

**Total:** ~23 core endpoints for MVP1

**Architecture Pattern:**
- Primary interface: Phoenix LiveView (WebSocket)
- REST API: Backend support + future mobile
- Auth: Session-based (Phoenix.Token)
- Authorization: Context-level user scoping

### 2. Required and Optional Parameters

#### Users Endpoints
**POST /api/users/register**
- Required: `email`, `password`, `password_confirmation`
- Optional: None

**GET /api/users/me**
- Required: Authentication token
- Optional: None

**PATCH /api/users/me**
- Required: Authentication token
- Optional: `preferences` (JSONB)

**POST /api/users/me/password**
- Required: `current_password`, `password`, `password_confirmation`

#### Strategies Endpoints
**GET /api/strategies**
- Required: Authentication
- Optional: `type`, `status`, `sort`, `order`, `page`, `per_page`

**POST /api/strategies**
- Required: `name`, `type`, `rules` (JSONB)
- Optional: None

**POST /api/strategies/generate** (AI)
- Required: `prompt`, `game_type`
- Optional: None
- Rate limit: 5/day/user

**POST /api/strategies/mix**
- Required: `name`, `strategy_ids` (2-3 IDs)
- Optional: None

**PATCH /api/strategies/:id**
- Required: `id`
- Optional: `name`, `rules` (if type=manual)

**DELETE /api/strategies/:id**
- Required: `id`

#### Draws Endpoints
**GET /api/draws**
- Required: None (public)
- Optional: `game_type`, `from_date`, `to_date`, `page`, `per_page`

**GET /api/draws/analysis**
- Required: `game_type`
- Optional: `period` (default: 32, max: 100)

#### Simulations Endpoints
**POST /api/simulations**
- Required: `strategy_id`, `target_draw_id`
- Optional: `options.max_attempts`, `options.timeout_seconds`

**GET /api/simulations/:id/progress**
- Required: `id`

#### Coupons Endpoints
**POST /api/coupons/generate**
- Required: `strategy_id`, `count`, `game_type`
- Range: count 1-10

### 3. Required DTOs and Embedded Schemas

Based on the JSONB structures and API responses, we need:

#### Embedded Schemas (Ecto)

**StrategyRules**
```elixir
defmodule NumbersEvolution.Strategies.StrategyRules do
  use Ecto.Schema
  
  @primary_key false
  embedded_schema do
    embeds_one :main_numbers, MainNumbers do
      field :ratio_even_odd, {:array, :integer}
      field :ratio_low_high, {:array, :integer}
      field :preferred_hot, {:array, :integer}
      field :preferred_cold, {:array, :integer}
      
      embeds_one :weights, Weights do
        field :hot, :float
        field :cold, :float
        field :random, :float
      end
    end
    
    embeds_one :euro_numbers, EuroNumbers do
      field :ratio_even_odd, {:array, :integer}
      field :preferred, {:array, :integer}
      
      embeds_one :weights, Weights do
        field :hot, :float
        field :random, :float
      end
    end
  end
end
```

**SimulationResult**
```elixir
defmodule NumbersEvolution.Simulations.SimulationResult do
  use Ecto.Schema
  
  @primary_key false
  embedded_schema do
    field :matched_main, {:array, :integer}
    field :matched_euro, {:array, :integer}
    field :attempts_count, :integer
    field :reason, :string  # for timeouts
    field :limit_reached, :string
    field :error_message, :string
    
    embeds_one :final_draw, FinalDraw do
      field :main_numbers, {:array, :integer}
      field :euro_numbers, {:array, :integer}
    end
  end
end
```

**DrawNumbers**
```elixir
defmodule NumbersEvolution.Draws.DrawNumbers do
  use Ecto.Schema
  
  @primary_key false
  embedded_schema do
    field :main_numbers, {:array, :integer}
    field :euro_numbers, {:array, :integer}
  end
end
```

#### View Schemas (JSON Rendering)

**UserJSON**
- `user` - basic user info
- `user_with_stats` - includes strategies_count, simulations_count, best_strategy

**StrategyJSON**
- `strategy` - basic strategy
- `strategy_with_simulations` - includes simulation history
- `strategy_with_stats` - includes aggregated performance metrics

**DrawJSON**
- `draw` - basic draw info
- `draw_analysis` - hot/cold number analysis

**SimulationJSON**
- `simulation` - basic simulation
- `simulation_with_details` - includes strategy and target_draw preloads

**RankingJSON**
- `strategy_ranking` - strategy with rank and performance metrics

**CouponJSON**
- `coupons` - array of generated number sets

### 4. Service Layer Extraction

Based on business logic complexity, extract to services:

#### NumbersEvolution.Strategies.AIService
**Responsibilities:**
- Rate limit checking (5/day/user)
- Prompt validation and sanitization (max 500 chars)
- Historical data fetching (last 32 draws)
- Hot/cold analysis
- AI API calls (OpenAI/Claude)
- JSON parsing and validation
- Fallback to templates on failure

**Key Functions:**
```elixir
@spec generate_strategy(User.t(), String.t(), String.t()) :: 
  {:ok, map()} | {:error, :rate_limit | :ai_error | :invalid_response}
def generate_strategy(user, prompt, game_type)

@spec check_rate_limit(User.t()) :: :ok | {:error, :rate_limit}
def check_rate_limit(user)

@spec mix_strategies(User.t(), [Strategy.t()]) :: 
  {:ok, map()} | {:error, :conflict, conflicts: list()}
def mix_strategies(user, strategies)
```

#### NumbersEvolution.Strategies.Generator
**Responsibilities:**
- Generate numbers from strategy rules
- Apply weights (hot/cold/random)
- Enforce ratio constraints (even/odd, low/high)
- Validate uniqueness
- Sort ascending

**Key Functions:**
```elixir
@spec generate_numbers(Strategy.t()) :: 
  {:ok, %{main: [integer()], euro: [integer()]}}
def generate_numbers(strategy)

@spec validate_rules(map()) :: :ok | {:error, list()}
def validate_rules(rules)
```

#### NumbersEvolution.Simulations.Runner
**Responsibilities:**
- Async simulation execution via GenServer
- Timeout and max_attempts enforcement
- Number generation in loop
- Grade I (5+2) matching
- Progress updates via PubSub
- Result persistence

**Key Functions:**
```elixir
@spec start_simulation(Strategy.t(), Draw.t(), keyword()) :: 
  {:ok, pid()} | {:error, term()}
def start_simulation(strategy, draw, opts)

@spec run_async(Simulation.t(), keyword()) :: Task.t()
def run_async(simulation, opts)
```

#### NumbersEvolution.Draws.Analyzer
**Responsibilities:**
- Hot/cold number calculation
- Frequency analysis
- Date range queries
- Caching (1 hour TTL)

**Key Functions:**
```elixir
@spec analyze_hot_cold(String.t(), pos_integer()) :: 
  %{main_numbers: map(), euro_numbers: map()}
def analyze_hot_cold(game_type, period \\ 32)

@spec get_hot_numbers(String.t(), pos_integer()) :: [integer()]
def get_hot_numbers(game_type, period)
```

#### NumbersEvolution.Strategies.PerformanceCalculator
**Responsibilities:**
- Median calculation via SQL
- Performance score updates
- Triggered after simulation completion

**Key Functions:**
```elixir
@spec recalculate_performance_score(uuid()) :: {:ok, Strategy.t()}
def recalculate_performance_score(strategy_id)

@spec update_after_simulation(Simulation.t()) :: :ok
def update_after_simulation(simulation)
```

### 5. Input Validation Plan

#### Context-Level Validation (Ecto Changesets)

**Users Context:**
```elixir
def registration_changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :password])
  |> validate_required([:email, :password])
  |> validate_email()
  |> validate_length(:password, min: 8)
  |> validate_password_strength()  # At least 1 digit
  |> validate_confirmation(:password, required: true)
  |> unique_constraint(:email)
  |> hash_password()
end
```

**Strategies Context:**
```elixir
def changeset(strategy, attrs) do
  strategy
  |> cast(attrs, [:name, :type, :status, :ai_prompt])
  |> validate_required([:name, :type])
  |> validate_length(:name, min: 3, max: 255)
  |> validate_inclusion(:type, ["manual", "ai_generated"])
  |> validate_inclusion(:status, ["active", "deleted", "archived"])
  |> cast_embed(:rules, required: true, with: &StrategyRules.changeset/2)
  |> validate_ai_prompt()
  |> validate_rules_logic()
end

defp validate_rules_logic(changeset) do
  validate_change(changeset, :rules, fn :rules, rules ->
    case Strategies.Validator.validate_rules(rules) do
      :ok -> []
      {:error, errors} -> [rules: errors]
    end
  end)
end
```

**Rules Validation (Strategies.Validator):**
```elixir
def validate_rules(%{main_numbers: main, euro_numbers: euro}) do
  with :ok <- validate_weights_sum(main.weights),
       :ok <- validate_weights_sum(euro.weights),
       :ok <- validate_ratio_sum(main.ratio_even_odd, 5),
       :ok <- validate_ratio_sum(main.ratio_low_high, 5),
       :ok <- validate_ratio_sum(euro.ratio_even_odd, 2),
       :ok <- validate_number_ranges(main.preferred_hot, 1..50),
       :ok <- validate_number_ranges(main.preferred_cold, 1..50),
       :ok <- validate_number_ranges(euro.preferred, 1..12) do
    :ok
  end
end

defp validate_weights_sum(weights) do
  sum = Map.values(weights) |> Enum.sum()
  if abs(sum - 1.0) < 0.001 do
    :ok
  else
    {:error, "Weights must sum to 1.0, got #{sum}"}
  end
end
```

**Simulations Context:**
```elixir
def changeset(simulation, attrs) do
  simulation
  |> cast(attrs, [:strategy_id, :target_draw_id, :attempts_count, 
                  :duration_seconds, :status, :started_at, :completed_at])
  |> validate_required([:strategy_id, :target_draw_id, :status])
  |> validate_number(:attempts_count, greater_than_or_equal_to: 0)
  |> validate_number(:duration_seconds, greater_than_or_equal_to: 0)
  |> validate_inclusion(:status, ["pending", "running", "success", "timeout", "error", "cancelled"])
  |> cast_embed(:result, with: &SimulationResult.changeset/2)
  |> foreign_key_constraint(:strategy_id)
  |> foreign_key_constraint(:target_draw_id)
  |> validate_completed_after_started()
end
```

#### Controller-Level Validation (Plug)

**Query Parameter Validation:**
```elixir
# lib/numbers_evolution_web/controllers/strategy_controller.ex
defmodule NumbersEvolutionWeb.StrategyController do
  use NumbersEvolutionWeb, :controller
  
  plug :validate_pagination_params when action in [:index]
  plug :validate_sort_params when action in [:index]
  
  defp validate_pagination_params(conn, _opts) do
    with {:ok, page} <- parse_int(conn.params["page"], default: 1, min: 1),
         {:ok, per_page} <- parse_int(conn.params["per_page"], default: 20, min: 1, max: 100) do
      assign(conn, :pagination, %{page: page, per_page: per_page})
    else
      {:error, field, reason} ->
        conn
        |> put_status(400)
        |> json(%{errors: %{field => [reason]}})
        |> halt()
    end
  end
end
```

**Rate Limiting Plug:**
```elixir
defmodule NumbersEvolutionWeb.Plugs.RateLimiter do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, opts) do
    user_id = conn.assigns.current_user.id
    limit = opts[:limit]
    window = opts[:window]
    key = "rate_limit:#{opts[:scope]}:#{user_id}"
    
    case check_rate_limit(key, limit, window) do
      {:ok, remaining} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
        
      {:error, retry_after} ->
        conn
        |> put_status(429)
        |> json(%{
          error: "Rate limit exceeded",
          retry_after: retry_after,
          limit: %{max: limit, remaining: 0}
        })
        |> halt()
    end
  end
end
```

### 6. Error Logging to Events Table

All significant errors and user actions logged to `events` table:

```elixir
defmodule NumbersEvolution.Events do
  def log_event(user, event_type, metadata \\ %{}) do
    %Event{}
    |> Event.changeset(%{
      user_id: user.id,
      event_type: event_type,
      metadata: metadata
    })
    |> Repo.insert()
  end
  
  # Usage in Strategies context
  def create_strategy(user, attrs) do
    Repo.transaction(fn ->
      case do_create_strategy(user, attrs) do
        {:ok, strategy} ->
          Events.log_event(user, "strategy_created", %{
            entity_type: "strategy",
            entity_id: strategy.id,
            strategy_type: strategy.type
          })
          strategy
          
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end
  
  # AI error logging
  def generate_with_ai(user, prompt) do
    case AIService.generate_strategy(user, prompt, "eurojackpot") do
      {:ok, strategy_attrs} ->
        Events.log_event(user, "ai_success", %{
          ai_provider: "claude",
          prompt_length: String.length(prompt)
        })
        {:ok, strategy_attrs}
        
      {:error, reason} = error ->
        Events.log_event(user, "ai_error", %{
          ai_provider: "claude",
          error_type: reason,
          prompt_length: String.length(prompt)
        })
        error
    end
  end
end
```

### 7. Security Threats

#### Identified Threats and Mitigations

**1. Unauthorized Data Access (CRITICAL)**
- Threat: User A accessing User B's strategies/simulations
- Mitigation: 
  - Enforce user scoping in all Context functions
  - Every query: `where: s.user_id == ^user.id`
  - Test coverage for isolation
  - Return 404 (not 403) to avoid enumeration

**2. AI Prompt Injection (HIGH)**
- Threat: Malicious prompts to extract system prompt or cause errors
- Mitigation:
  - Max prompt length: 500 chars
  - Sanitize input (remove special chars)
  - System prompt guards
  - Rate limiting: 5/day/user
  - Validate AI response format

**3. Rate Limit Bypass (HIGH)**
- Threat: Multiple accounts or session manipulation
- Mitigation:
  - Track by user_id in database
  - ETS cache for fast lookups
  - IP-based fallback rate limiting
  - Monitor for abuse patterns

**4. JSONB Injection (MEDIUM)**
- Threat: Invalid JSON in rules causing errors or exploits
- Mitigation:
  - Embedded schemas for type checking
  - Strict validation before persistence
  - Never use raw JSON.decode without schema validation
  - Database constraints on JSONB fields

**5. SQL Injection (LOW - Ecto protection)**
- Threat: Raw SQL injection via parameters
- Mitigation:
  - Use Ecto parameterized queries exclusively
  - Never use string interpolation in queries
  - Validate all IDs as UUIDs

**6. XSS via API Responses (LOW)**
- Threat: Malicious content in strategy names, prompts
- Mitigation:
  - Phoenix.HTML escaping in LiveView
  - JSON API doesn't render HTML
  - Validate max lengths

**7. DoS via Expensive Operations (MEDIUM)**
- Threat: Triggering many simulations, AI calls
- Mitigation:
  - Rate limiting per operation type
  - Simulation queue with max depth
  - Timeout enforcement (300s)
  - Max attempts limit (1M)

**8. Timing Attacks (LOW)**
- Threat: User enumeration via timing differences
- Mitigation:
  - Consistent response times for 404 vs unauthorized
  - Bcrypt timing resistance for passwords

### 8. Error Scenarios and Status Codes

#### Users

**POST /api/users/register**
- 201: Success
- 400: Validation errors (email format, password length, confirmation mismatch)
- 409: Email already taken (could use 400, but 409 more semantic)
- 500: Unexpected error

**GET /api/users/me**
- 200: Success
- 401: Invalid/expired token
- 500: Unexpected error

**PATCH /api/users/me**
- 200: Success
- 400: Invalid preferences JSON
- 401: Unauthorized
- 500: Unexpected error

**POST /api/users/me/password**
- 200: Success
- 400: Current password incorrect, or validation errors
- 401: Unauthorized
- 500: Unexpected error

#### Strategies

**GET /api/strategies**
- 200: Success (empty array if none)
- 400: Invalid query parameters
- 401: Unauthorized
- 500: Unexpected error

**GET /api/strategies/:id**
- 200: Success
- 401: Unauthorized
- 404: Not found or doesn't belong to user
- 500: Unexpected error

**POST /api/strategies**
- 201: Success
- 400: Validation errors
- 401: Unauthorized
- 422: Business logic error (invalid rules combination)
- 500: Unexpected error

**POST /api/strategies/generate**
- 201: Success
- 400: Invalid prompt (length, format)
- 401: Unauthorized
- 429: Rate limit exceeded
- 503: AI service unavailable
- 500: Unexpected error

**POST /api/strategies/mix**
- 201: Success
- 400: Invalid strategy_ids count (not 2-3)
- 401: Unauthorized
- 404: One or more strategies not found
- 409: Conflicting rules cannot be merged
- 429: Rate limit exceeded
- 503: AI service unavailable
- 500: Unexpected error

**PATCH /api/strategies/:id**
- 200: Success
- 400: Validation errors
- 401: Unauthorized
- 403: Cannot modify AI-generated rules
- 404: Not found
- 500: Unexpected error

**DELETE /api/strategies/:id**
- 204: Success (soft delete)
- 401: Unauthorized
- 404: Not found
- 500: Unexpected error

#### Draws

**GET /api/draws**
- 200: Success (public endpoint)
- 400: Invalid query parameters
- 500: Unexpected error

**GET /api/draws/:id**
- 200: Success
- 404: Not found
- 500: Unexpected error

**GET /api/draws/latest**
- 200: Success
- 400: Missing or invalid game_type
- 404: No draws found for game_type
- 500: Unexpected error

**GET /api/draws/analysis**
- 200: Success
- 400: Invalid game_type or period
- 404: Insufficient draws for analysis
- 500: Unexpected error

#### Simulations

**GET /api/simulations**
- 200: Success
- 400: Invalid query parameters
- 401: Unauthorized
- 500: Unexpected error

**GET /api/simulations/:id**
- 200: Success
- 401: Unauthorized
- 404: Not found or doesn't belong to user
- 500: Unexpected error

**POST /api/simulations**
- 202: Accepted (async processing)
- 400: Invalid strategy_id or target_draw_id, or invalid options
- 401: Unauthorized
- 429: Rate limit exceeded
- 500: Unexpected error

**GET /api/simulations/:id/progress**
- 200: Success
- 401: Unauthorized
- 404: Not found
- 500: Unexpected error

**POST /api/simulations/:id/cancel** (MVP2)
- 200: Success
- 401: Unauthorized
- 404: Not found
- 409: Already completed, cannot cancel
- 500: Unexpected error

#### Rankings

**GET /api/rankings/strategies**
- 200: Success (empty array if no strategies with simulations)
- 400: Invalid query parameters
- 401: Unauthorized
- 500: Unexpected error

#### Coupons

**POST /api/coupons/generate**
- 200: Success
- 400: Invalid count or strategy_id
- 401: Unauthorized
- 404: Strategy not found
- 422: Cannot generate unique coupons with these rules
- 500: Unexpected error

**POST /api/coupons/generate/top**
- 200: Success
- 400: Invalid count
- 401: Unauthorized
- 404: No strategies with simulations found
- 500: Unexpected error

</analysis>

---

## 1. Implementation Overview

### Purpose

This implementation plan provides a comprehensive guide for building the Numbers Evolution REST API using Phoenix/Elixir. The API serves as backend support for the primary LiveView interface and enables future mobile/external integrations.

### Architecture

- **Framework:** Phoenix 1.7+ with Elixir 1.15+
- **Database:** PostgreSQL 14+ with Ecto 3.x
- **Authentication:** Session-based (phx.gen.auth) + Phoenix.Token for API
- **Authorization:** Context-level user scoping
- **Real-time:** Phoenix PubSub + LiveView (primary), REST for polling
- **AI Integration:** OpenAI GPT-4 Turbo or Claude 3.5 Sonnet
- **Background Jobs:** Task.async with GenServer supervision

### Scope

**MVP1 Endpoints (Week 1-6):**
- Users: 4 endpoints
- Strategies: 5 endpoints (AI optional/fallback)
- Draws: 4 endpoints
- Simulations: 3 endpoints (single simulations only)
- Rankings: 1 endpoint (user scope)
- Coupons: 2 endpoints

**Total:** 19 core endpoints

**MVP2 Features (Post-MVP):**
- Multi-simulations
- Simulation cancellation
- Global rankings
- Strategy mixes

---

## 2. Project Structure

```
lib/
├── numbers_evolution/
│   ├── accounts/
│   │   ├── user.ex                    # Schema
│   │   ├── user_token.ex              # Auth token schema
│   │   └── user_notifier.ex           # Email (post-MVP)
│   │
│   ├── strategies/
│   │   ├── strategy.ex                # Schema
│   │   ├── strategy_rules.ex          # Embedded schema
│   │   ├── generator.ex               # Number generation
│   │   ├── validator.ex               # Rules validation
│   │   ├── ai_service.ex              # AI integration
│   │   └── performance_calculator.ex  # Score calculation
│   │
│   ├── draws/
│   │   ├── draw.ex                    # Schema
│   │   ├── draw_numbers.ex            # Embedded schema
│   │   └── analyzer.ex                # Hot/cold analysis
│   │
│   ├── simulations/
│   │   ├── simulation.ex              # Schema
│   │   ├── simulation_result.ex       # Embedded schema
│   │   ├── runner.ex                  # GenServer for execution
│   │   └── supervisor.ex              # DynamicSupervisor
│   │
│   ├── events/
│   │   └── event.ex                   # Analytics schema
│   │
│   └── repo.ex
│
├── numbers_evolution_web/
│   ├── controllers/
│   │   ├── user_controller.ex
│   │   ├── strategy_controller.ex
│   │   ├── draw_controller.ex
│   │   ├── simulation_controller.ex
│   │   ├── ranking_controller.ex
│   │   └── coupon_controller.ex
│   │
│   ├── views/ (JSON rendering)
│   │   ├── user_json.ex
│   │   ├── strategy_json.ex
│   │   ├── draw_json.ex
│   │   ├── simulation_json.ex
│   │   ├── ranking_json.ex
│   │   ├── coupon_json.ex
│   │   └── error_json.ex
│   │
│   ├── plugs/
│   │   ├── rate_limiter.ex           # Rate limiting
│   │   ├── api_auth.ex                # Token authentication
│   │   └── ensure_authenticated.ex    # Auth check
│   │
│   └── router.ex
│
└── numbers_evolution_web.ex
```

---

## 3. Context Layer Implementation

### 3.1 Accounts Context

**Location:** `lib/numbers_evolution/accounts.ex`

**Responsibilities:**
- User registration and authentication
- Password management
- User preferences
- Session management via phx.gen.auth

**Key Functions:**

```elixir
defmodule NumbersEvolution.Accounts do
  import Ecto.Query
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Accounts.{User, UserToken}
  
  ## Registration
  
  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end
  
  ## Authentication
  
  @spec get_user_by_email_and_password(String.t(), String.t()) :: 
    {:ok, User.t()} | {:error, :invalid_credentials}
  def get_user_by_email_and_password(email, password)
  
  @spec generate_user_session_token(User.t()) :: String.t()
  def generate_user_session_token(user)
  
  @spec verify_user_token(String.t()) :: {:ok, User.t()} | {:error, :invalid}
  def verify_user_token(token)
  
  ## User management
  
  @spec get_user!(id :: binary()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)
  
  @spec update_user_preferences(User.t(), map()) :: 
    {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_preferences(user, preferences)
  
  @spec change_user_password(User.t(), String.t(), map()) :: 
    {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def change_user_password(user, current_password, attrs)
  
  ## Stats
  
  @spec get_user_stats(User.t()) :: map()
  def get_user_stats(user) do
    %{
      strategies_count: count_user_strategies(user),
      simulations_count: count_user_simulations(user),
      best_strategy: get_user_best_strategy(user)
    }
  end
end
```

### 3.2 Strategies Context

**Location:** `lib/numbers_evolution/strategies.ex`

**Responsibilities:**
- Strategy CRUD (user-scoped)
- AI generation coordination
- Strategy mixing
- Performance score management

**Key Functions:**

```elixir
defmodule NumbersEvolution.Strategies do
  import Ecto.Query
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Strategies.{Strategy, AIService, Generator, PerformanceCalculator}
  alias NumbersEvolution.Accounts.User
  
  ## Queries (always user-scoped)
  
  @spec list_strategies(User.t(), keyword()) :: [Strategy.t()]
  def list_strategies(%User{id: user_id}, opts \\ []) do
    from(s in Strategy, where: s.user_id == ^user_id)
    |> apply_filters(opts)
    |> apply_sorting(opts)
    |> paginate(opts)
    |> Repo.all()
  end
  
  @spec get_strategy!(User.t(), binary()) :: Strategy.t()
  def get_strategy!(%User{id: user_id}, id) do
    from(s in Strategy, where: s.id == ^id and s.user_id == ^user_id)
    |> Repo.one!()
  end
  
  @spec get_strategy_with_stats(User.t(), binary()) :: map()
  def get_strategy_with_stats(user, id)
  
  ## Creation
  
  @spec create_strategy(User.t(), map()) :: 
    {:ok, Strategy.t()} | {:error, Ecto.Changeset.t()}
  def create_strategy(%User{id: user_id} = user, attrs) do
    result =
      %Strategy{user_id: user_id}
      |> Strategy.changeset(attrs)
      |> Repo.insert()
    
    case result do
      {:ok, strategy} ->
        log_strategy_created(user, strategy)
        {:ok, strategy}
      error -> error
    end
  end
  
  @spec generate_with_ai(User.t(), String.t(), String.t()) :: 
    {:ok, Strategy.t()} | {:error, atom()}
  def generate_with_ai(user, prompt, game_type) do
    with {:ok, strategy_attrs} <- AIService.generate_strategy(user, prompt, game_type),
         {:ok, strategy} <- create_strategy(user, strategy_attrs) do
      {:ok, strategy}
    end
  end
  
  @spec mix_strategies(User.t(), String.t(), [binary()]) :: 
    {:ok, Strategy.t()} | {:error, atom()}
  def mix_strategies(user, name, strategy_ids) do
    strategies = Enum.map(strategy_ids, &get_strategy!(user, &1))
    
    with {:ok, mixed_attrs} <- AIService.mix_strategies(user, name, strategies),
         {:ok, strategy} <- create_strategy(user, mixed_attrs) do
      {:ok, strategy}
    end
  end
  
  ## Updates
  
  @spec update_strategy(User.t(), binary(), map()) :: 
    {:ok, Strategy.t()} | {:error, Ecto.Changeset.t()}
  def update_strategy(user, id, attrs) do
    strategy = get_strategy!(user, id)
    
    strategy
    |> Strategy.update_changeset(attrs)
    |> Repo.update()
  end
  
  @spec delete_strategy(User.t(), binary()) :: {:ok, Strategy.t()}
  def delete_strategy(user, id) do
    strategy = get_strategy!(user, id)
    
    strategy
    |> Strategy.changeset(%{status: "deleted"})
    |> Repo.update()
  end
  
  ## Performance
  
  @spec update_strategy_performance_after_simulation(Simulation.t()) :: :ok
  def update_strategy_performance_after_simulation(simulation) do
    if simulation.strategy_id do
      PerformanceCalculator.recalculate_performance_score(simulation.strategy_id)
    end
    :ok
  end
end
```

### 3.3 Draws Context

**Location:** `lib/numbers_evolution/draws.ex`

**Responsibilities:**
- Historical draw queries (public)
- Hot/cold number analysis
- Latest draw retrieval

**Key Functions:**

```elixir
defmodule NumbersEvolution.Draws do
  import Ecto.Query
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Draws.{Draw, Analyzer}
  
  ## Queries (public - no user scoping)
  
  @spec list_draws(keyword()) :: [Draw.t()]
  def list_draws(opts \\ []) do
    from(d in Draw)
    |> filter_by_game_type(opts[:game_type])
    |> filter_by_date_range(opts[:from_date], opts[:to_date])
    |> order_by([d], desc: d.draw_date)
    |> paginate(opts)
    |> Repo.all()
  end
  
  @spec get_draw!(binary()) :: Draw.t()
  def get_draw!(id), do: Repo.get!(Draw, id)
  
  @spec get_latest_draw(String.t()) :: Draw.t() | nil
  def get_latest_draw(game_type) do
    from(d in Draw,
      where: d.game_type == ^game_type,
      order_by: [desc: d.draw_date],
      limit: 1
    )
    |> Repo.one()
  end
  
  @spec recent_draws(String.t(), pos_integer()) :: [Draw.t()]
  def recent_draws(game_type, limit \\ 32) do
    from(d in Draw,
      where: d.game_type == ^game_type,
      order_by: [desc: d.draw_date],
      limit: ^limit
    )
    |> Repo.all()
  end
  
  ## Analysis
  
  @spec analyze_hot_cold(String.t(), pos_integer()) :: map()
  def analyze_hot_cold(game_type, period \\ 32) do
    Analyzer.analyze_hot_cold(game_type, period)
  end
  
  ## Admin (seeding)
  
  @spec create_draw(map()) :: {:ok, Draw.t()} | {:error, Ecto.Changeset.t()}
  def create_draw(attrs) do
    %Draw{}
    |> Draw.changeset(attrs)
    |> Repo.insert()
  end
end
```

### 3.4 Simulations Context

**Location:** `lib/numbers_evolution/simulations.ex`

**Responsibilities:**
- Simulation CRUD (user-scoped)
- Async execution coordination
- Progress tracking
- Result persistence

**Key Functions:**

```elixir
defmodule NumbersEvolution.Simulations do
  import Ecto.Query
  alias NumbersEvolution.Repo
  alias NumbersEvolution.Simulations.{Simulation, Runner}
  alias NumbersEvolution.{Strategies, Draws}
  alias NumbersEvolution.Accounts.User
  
  ## Queries
  
  @spec list_simulations(User.t(), keyword()) :: [Simulation.t()]
  def list_simulations(%User{id: user_id}, opts \\ []) do
    from(s in Simulation, where: s.user_id == ^user_id)
    |> apply_filters(opts)
    |> order_by([s], desc: s.inserted_at)
    |> paginate(opts)
    |> Repo.all()
  end
  
  @spec get_simulation!(User.t(), binary()) :: Simulation.t()
  def get_simulation!(%User{id: user_id}, id) do
    from(s in Simulation, where: s.id == ^id and s.user_id == ^user_id)
    |> Repo.one!()
  end
  
  @spec get_simulation_with_details(User.t(), binary()) :: Simulation.t()
  def get_simulation_with_details(user, id) do
    get_simulation!(user, id)
    |> Repo.preload([:strategy, :target_draw])
  end
  
  ## Creation and Execution
  
  @spec start_simulation(User.t(), map()) :: 
    {:ok, Simulation.t()} | {:error, Ecto.Changeset.t() | atom()}
  def start_simulation(%User{id: user_id} = user, attrs) do
    with {:ok, strategy} <- validate_strategy(user, attrs["strategy_id"]),
         {:ok, draw} <- validate_draw(attrs["target_draw_id"]),
         {:ok, simulation} <- create_simulation_record(user_id, attrs) do
      
      # Start async execution
      Task.start(fn ->
        Runner.run_async(simulation, strategy, draw, parse_options(attrs["options"]))
      end)
      
      {:ok, simulation}
    end
  end
  
  @spec complete_simulation(binary(), atom(), map()) :: {:ok, Simulation.t()}
  def complete_simulation(simulation_id, status, result_data) do
    simulation = Repo.get!(Simulation, simulation_id)
    
    {:ok, updated} = 
      Repo.transaction(fn ->
        simulation
        |> Simulation.completion_changeset(status, result_data)
        |> Repo.update!()
        |> tap(fn sim ->
          # Trigger performance recalculation
          Strategies.update_strategy_performance_after_simulation(sim)
          
          # Broadcast completion
          Phoenix.PubSub.broadcast(
            NumbersEvolution.PubSub,
            "simulation:#{simulation_id}",
            {:simulation_complete, sim}
          )
        end)
      end)
    
    {:ok, updated}
  end
  
  @spec get_simulation_progress(User.t(), binary()) :: map()
  def get_simulation_progress(user, id) do
    simulation = get_simulation!(user, id)
    
    %{
      id: simulation.id,
      status: simulation.status,
      attempts_count: simulation.attempts_count,
      duration_seconds: simulation.duration_seconds,
      started_at: simulation.started_at
    }
  end
  
  ## Private
  
  defp create_simulation_record(user_id, attrs) do
    %Simulation{user_id: user_id}
    |> Simulation.changeset(%{
      strategy_id: attrs["strategy_id"],
      target_draw_id: attrs["target_draw_id"],
      status: "pending"
    })
    |> Repo.insert()
  end
end
```

---

## 4. Controller Implementation

### 4.1 Router Configuration

**Location:** `lib/numbers_evolution_web/router.ex`

```elixir
defmodule NumbersEvolutionWeb.Router do
  use NumbersEvolutionWeb, :router
  
  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
  end
  
  pipeline :api_auth do
    plug :accepts, ["json"]
    plug NumbersEvolutionWeb.Plugs.APIAuth
  end
  
  # Public API routes
  scope "/api", NumbersEvolutionWeb do
    pipe_through :api
    
    # Authentication
    post "/users/register", UserController, :register
    post "/auth/token", UserController, :create_token
    
    # Public draws
    get "/draws", DrawController, :index
    get "/draws/latest", DrawController, :latest
    get "/draws/analysis", DrawController, :analysis
    get "/draws/:id", DrawController, :show
  end
  
  # Authenticated API routes
  scope "/api", NumbersEvolutionWeb do
    pipe_through :api_auth
    
    # Users
    get "/users/me", UserController, :show
    patch "/users/me", UserController, :update
    post "/users/me/password", UserController, :change_password
    
    # Strategies
    get "/strategies", StrategyController, :index
    get "/strategies/:id", StrategyController, :show
    post "/strategies", StrategyController, :create
    patch "/strategies/:id", StrategyController, :update
    delete "/strategies/:id", StrategyController, :delete
    
    # AI Strategy generation (rate limited)
    post "/strategies/generate", StrategyController, :generate,
      private: %{rate_limit: [limit: 5, window: 86400, scope: "ai_generation"]}
    
    # Strategy mixing (rate limited)
    post "/strategies/mix", StrategyController, :mix,
      private: %{rate_limit: [limit: 10, window: 86400, scope: "strategy_mix"]}
    
    # Simulations
    get "/simulations", SimulationController, :index
    get "/simulations/:id", SimulationController, :show
    post "/simulations", SimulationController, :create
    get "/simulations/:id/progress", SimulationController, :progress
    
    # Rankings
    get "/rankings/strategies", RankingController, :strategies
    
    # Coupons
    post "/coupons/generate", CouponController, :generate
    post "/coupons/generate/top", CouponController, :generate_from_top
  end
end
```

### 4.2 Example Controller: StrategyController

**Location:** `lib/numbers_evolution_web/controllers/strategy_controller.ex`

```elixir
defmodule NumbersEvolutionWeb.StrategyController do
  use NumbersEvolutionWeb, :controller
  
  alias NumbersEvolution.Strategies
  alias NumbersEvolution.Accounts.User
  
  action_fallback NumbersEvolutionWeb.FallbackController
  
  # GET /api/strategies
  def index(conn, params) do
    user = conn.assigns.current_user
    
    opts = [
      type: params["type"],
      status: params["status"],
      sort: params["sort"] || "inserted_at",
      order: params["order"] || "desc",
      page: parse_int(params["page"], default: 1),
      per_page: parse_int(params["per_page"], default: 20, max: 100)
    ]
    
    strategies = Strategies.list_strategies(user, opts)
    total_count = Strategies.count_strategies(user, opts)
    
    conn
    |> put_status(:ok)
    |> render(:index, strategies: strategies, meta: pagination_meta(opts, total_count))
  end
  
  # GET /api/strategies/:id
  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    
    strategy = Strategies.get_strategy_with_stats(user, id)
    
    conn
    |> put_status(:ok)
    |> render(:show, strategy: strategy)
  end
  
  # POST /api/strategies
  def create(conn, %{"strategy" => strategy_params}) do
    user = conn.assigns.current_user
    
    case Strategies.create_strategy(user, strategy_params) do
      {:ok, strategy} ->
        conn
        |> put_status(:created)
        |> render(:show, strategy: strategy)
        
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end
  
  # POST /api/strategies/generate
  def generate(conn, %{"prompt" => prompt, "game_type" => game_type}) do
    user = conn.assigns.current_user
    
    case Strategies.generate_with_ai(user, prompt, game_type) do
      {:ok, strategy} ->
        conn
        |> put_status(:created)
        |> render(:show_with_reasoning, strategy: strategy)
        
      {:error, :rate_limit} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "AI generation limit exceeded. You can generate 5 strategies per day.",
          retry_after: calculate_retry_after(user)
        })
        
      {:error, :ai_error} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          error: "AI service temporarily unavailable. Please try again or create a manual strategy.",
          fallback_action: "create_manual"
        })
        
      {:error, changeset} ->
        {:error, changeset}
    end
  end
  
  # POST /api/strategies/mix
  def mix(conn, %{"name" => name, "strategy_ids" => strategy_ids}) do
    user = conn.assigns.current_user
    
    case Strategies.mix_strategies(user, name, strategy_ids) do
      {:ok, strategy} ->
        conn
        |> put_status(:created)
        |> render(:show_with_components, strategy: strategy)
        
      {:error, :conflict, conflicts: conflicts} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "These strategies have conflicting rules that cannot be merged",
          conflicts: conflicts
        })
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # PATCH /api/strategies/:id
  def update(conn, %{"id" => id, "strategy" => strategy_params}) do
    user = conn.assigns.current_user
    
    case Strategies.update_strategy(user, id, strategy_params) do
      {:ok, strategy} ->
        conn
        |> put_status(:ok)
        |> render(:show, strategy: strategy)
        
      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "AI-generated strategy rules cannot be modified. You can change the name or create a new strategy."
        })
        
      {:error, changeset} ->
        {:error, changeset}
    end
  end
  
  # DELETE /api/strategies/:id
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    
    case Strategies.delete_strategy(user, id) do
      {:ok, _strategy} ->
        send_resp(conn, :no_content, "")
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  ## Private helpers
  
  defp parse_int(nil, opts), do: Keyword.get(opts, :default, 1)
  defp parse_int(value, opts) do
    case Integer.parse(value) do
      {int, ""} ->
        min = Keyword.get(opts, :min)
        max = Keyword.get(opts, :max)
        
        cond do
          min && int < min -> Keyword.get(opts, :default, min)
          max && int > max -> max
          true -> int
        end
        
      _ -> Keyword.get(opts, :default, 1)
    end
  end
  
  defp pagination_meta(opts, total_count) do
    page = opts[:page]
    per_page = opts[:per_page]
    total_pages = ceil(total_count / per_page)
    
    %{
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end
end
```

### 4.3 FallbackController

**Location:** `lib/numbers_evolution_web/controllers/fallback_controller.ex`

```elixir
defmodule NumbersEvolutionWeb.FallbackController do
  use NumbersEvolutionWeb, :controller
  
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, changeset: changeset)
  end
  
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: NumbersEvolutionWeb.ErrorJSON)
    |> render(:not_found)
  end
  
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: NumbersEvolutionWeb.ErrorJSON)
    |> render(:unauthorized)
  end
  
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: NumbersEvolutionWeb.ErrorJSON)
    |> render(:forbidden)
  end
end
```

---

## 5. JSON Rendering

### 5.1 StrategyJSON View

**Location:** `lib/numbers_evolution_web/controllers/strategy_json.ex`

```elixir
defmodule NumbersEvolutionWeb.StrategyJSON do
  alias NumbersEvolution.Strategies.Strategy
  
  def index(%{strategies: strategies, meta: meta}) do
    %{
      data: for(strategy <- strategies, do: data(strategy)),
      meta: meta
    }
  end
  
  def show(%{strategy: strategy}) do
    %{data: data(strategy)}
  end
  
  def show_with_reasoning(%{strategy: strategy}) do
    %{
      data: 
        strategy
        |> data()
        |> Map.put(:reasoning, strategy.reasoning)
    }
  end
  
  def show_with_components(%{strategy: strategy}) do
    %{
      data:
        strategy
        |> data()
        |> Map.put(:component_strategies, strategy.component_strategies)
    }
  end
  
  defp data(%Strategy{} = strategy) do
    %{
      id: strategy.id,
      name: strategy.name,
      type: strategy.type,
      status: strategy.status,
      rules: strategy.rules,
      performance_score: strategy.performance_score,
      simulations_count: Map.get(strategy, :simulations_count),
      ai_prompt: strategy.ai_prompt,
      inserted_at: strategy.inserted_at,
      updated_at: strategy.updated_at
    }
  end
end
```

### 5.2 ErrorJSON View

**Location:** `lib/numbers_evolution_web/controllers/error_json.ex`

```elixir
defmodule NumbersEvolutionWeb.ErrorJSON do
  def error(%{changeset: changeset}) do
    %{
      errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    }
  end
  
  def not_found(_assigns) do
    %{error: "Resource not found"}
  end
  
  def unauthorized(_assigns) do
    %{error: "Unauthorized"}
  end
  
  def forbidden(_assigns) do
    %{error: "Forbidden"}
  end
  
  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
```

---

## 6. Service Layer Implementation

### 6.1 AI Service

**Location:** `lib/numbers_evolution/strategies/ai_service.ex`

```elixir
defmodule NumbersEvolution.Strategies.AIService do
  require Logger
  alias NumbersEvolution.{Draws, Events, Repo}
  alias NumbersEvolution.Accounts.User
  
  @rate_limit_per_day 5
  @prompt_max_length 500
  @timeout_ms 30_000
  
  @spec generate_strategy(User.t(), String.t(), String.t()) :: 
    {:ok, map()} | {:error, :rate_limit | :ai_error | :invalid_response}
  def generate_strategy(user, prompt, game_type) do
    with :ok <- check_rate_limit(user),
         :ok <- validate_prompt(prompt),
         {:ok, historical_data} <- fetch_historical_data(game_type),
         {:ok, ai_response} <- call_ai_api(user, prompt, historical_data, game_type),
         {:ok, parsed} <- parse_and_validate_response(ai_response) do
      
      Events.log_event(user, "ai_success", %{
        ai_provider: ai_provider(),
        prompt_length: String.length(prompt)
      })
      
      {:ok, parsed}
    else
      {:error, reason} = error ->
        Events.log_event(user, "ai_error", %{
          ai_provider: ai_provider(),
          error_type: reason,
          prompt_length: String.length(prompt)
        })
        error
    end
  end
  
  @spec mix_strategies(User.t(), String.t(), [Strategy.t()]) :: 
    {:ok, map()} | {:error, :conflict | :ai_error}
  def mix_strategies(user, name, strategies) do
    with :ok <- check_conflicts(strategies),
         {:ok, ai_response} <- call_mix_api(user, name, strategies),
         {:ok, parsed} <- parse_and_validate_response(ai_response) do
      {:ok, Map.put(parsed, :name, name)}
    end
  end
  
  ## Private
  
  defp check_rate_limit(user) do
    count = count_todays_ai_generations(user)
    
    if count >= @rate_limit_per_day do
      {:error, :rate_limit}
    else
      :ok
    end
  end
  
  defp count_todays_ai_generations(user) do
    today = Date.utc_today()
    
    from(e in Event,
      where: e.user_id == ^user.id,
      where: e.event_type == "ai_success",
      where: fragment("DATE(?)", e.inserted_at) == ^today
    )
    |> Repo.aggregate(:count)
  end
  
  defp validate_prompt(prompt) do
    cond do
      byte_size(prompt) > @prompt_max_length ->
        {:error, :prompt_too_long}
        
      byte_size(prompt) < 10 ->
        {:error, :prompt_too_short}
        
      true ->
        :ok
    end
  end
  
  defp fetch_historical_data(game_type) do
    draws = Draws.recent_draws(game_type, 32)
    analysis = Draws.analyze_hot_cold(game_type, 32)
    
    {:ok, %{draws: draws, analysis: analysis}}
  end
  
  defp call_ai_api(user, prompt, historical_data, game_type) do
    system_prompt = build_system_prompt()
    user_prompt = build_user_prompt(prompt, historical_data, game_type)
    
    request_body = %{
      model: model_name(),
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_prompt}
      ],
      temperature: 0.7,
      max_tokens: 1000
    }
    
    case http_client().post(api_url(), request_body, 
           headers: auth_headers(), 
           timeout: @timeout_ms) do
      {:ok, %{status: 200, body: body}} ->
        extract_content(body)
        
      {:ok, %{status: 429}} ->
        {:error, :rate_limit}
        
      {:ok, %{status: status}} when status >= 500 ->
        {:error, :ai_error}
        
      {:error, _reason} ->
        {:error, :ai_error}
    end
  rescue
    _exception -> {:error, :ai_error}
  end
  
  defp parse_and_validate_response(response) do
    with {:ok, parsed} <- Jason.decode(response),
         :ok <- validate_strategy_structure(parsed) do
      {:ok, parsed}
    else
      _ -> {:error, :invalid_response}
    end
  end
  
  defp build_system_prompt do
    """
    You are a lottery strategy expert. Generate a strategy for Eurojackpot.
    You must ONLY return valid JSON in the exact format specified.
    Do not include any other text, explanations, or markdown.
    
    Output format (JSON only):
    {
      "strategy_name": "string",
      "description": "string",
      "reasoning": "string explaining the strategy logic",
      "game_type": "eurojackpot",
      "rules": {
        "main_numbers": {
          "ratio_even_odd": [2, 3],
          "ratio_low_high": [3, 2],
          "preferred_hot": [7, 23, 34],
          "preferred_cold": [1, 50],
          "weights": {
            "hot": 0.4,
            "cold": 0.2,
            "random": 0.4
          }
        },
        "euro_numbers": {
          "ratio_even_odd": [1, 1],
          "preferred": [3, 9],
          "weights": {
            "hot": 0.5,
            "random": 0.5
          }
        }
      }
    }
    
    Ensure:
    - Weights must sum to 1.0
    - ratio_even_odd for main_numbers must sum to 5
    - ratio_low_high for main_numbers must sum to 5
    - ratio_even_odd for euro_numbers must sum to 2
    - All numbers in preferred lists must be in valid ranges
    """
  end
  
  defp build_user_prompt(prompt, historical_data, _game_type) do
    hot_main = Enum.take(historical_data.analysis.main_numbers.hot, 5)
    cold_main = Enum.take(historical_data.analysis.main_numbers.cold, 5)
    hot_euro = Enum.take(historical_data.analysis.euro_numbers.hot, 3)
    
    """
    USER REQUEST: "#{prompt}"
    
    HISTORICAL DATA (last 32 draws):
    - Hot main numbers: #{format_frequencies(hot_main)}
    - Cold main numbers: #{format_frequencies(cold_main)}
    - Hot euro numbers: #{format_frequencies(hot_euro)}
    
    Generate a strategy based on this request and data.
    Return ONLY valid JSON, no other text.
    """
  end
  
  defp format_frequencies(numbers) do
    numbers
    |> Enum.map(fn %{number: n, frequency: f} -> "#{n} (#{f}x)" end)
    |> Enum.join(", ")
  end
  
  ## Configuration
  
  defp ai_provider, do: Application.get_env(:numbers_evolution, :ai_provider, :claude)
  defp model_name, do: Application.get_env(:numbers_evolution, :ai_model, "claude-3-5-sonnet-20241022")
  defp api_url, do: "https://api.anthropic.com/v1/messages"
  defp http_client, do: Application.get_env(:numbers_evolution, :http_client, Req)
  
  defp auth_headers do
    api_key = System.get_env("ANTHROPIC_API_KEY")
    
    [
      {"anthropic-version", "2023-06-01"},
      {"x-api-key", api_key},
      {"content-type", "application/json"}
    ]
  end
  
  defp extract_content(%{"content" => [%{"text" => text} | _]}), do: {:ok, text}
  defp extract_content(_), do: {:error, :invalid_response}
end
```

### 6.2 Number Generator

**Location:** `lib/numbers_evolution/strategies/generator.ex`

```elixir
defmodule NumbersEvolution.Strategies.Generator do
  alias NumbersEvolution.Strategies.Strategy
  
  @spec generate_numbers(Strategy.t()) :: 
    {:ok, %{main: [integer()], euro: [integer()]}}
  def generate_numbers(%Strategy{rules: rules}) do
    main_numbers = generate_main_numbers(rules.main_numbers)
    euro_numbers = generate_euro_numbers(rules.euro_numbers)
    
    {:ok, %{main: Enum.sort(main_numbers), euro: Enum.sort(euro_numbers)}}
  end
  
  ## Main Numbers (5 from 1-50)
  
  defp generate_main_numbers(rules) do
    pools = build_main_pools(rules)
    [even_count, odd_count] = rules.ratio_even_odd
    [low_count, high_count] = rules.ratio_low_high
    
    generate_with_constraints(pools, rules.weights, 5, %{
      even: even_count,
      odd: odd_count,
      low: low_count,
      high: high_count
    })
  end
  
  defp build_main_pools(rules) do
    all_numbers = MapSet.new(1..50)
    hot_set = MapSet.new(rules.preferred_hot || [])
    cold_set = MapSet.new(rules.preferred_cold || [])
    random_set = MapSet.difference(all_numbers, MapSet.union(hot_set, cold_set))
    
    %{
      hot: MapSet.to_list(hot_set),
      cold: MapSet.to_list(cold_set),
      random: MapSet.to_list(random_set)
    }
  end
  
  defp generate_with_constraints(pools, weights, count, constraints) do
    do_generate_with_constraints(pools, weights, [], count, constraints)
  end
  
  defp do_generate_with_constraints(_pools, _weights, selected, 0, _constraints) do
    selected
  end
  
  defp do_generate_with_constraints(pools, weights, selected, remaining, constraints) do
    # Select pool based on weights
    pool_name = weighted_random_pool(weights)
    available = pools[pool_name]
    
    # Filter by constraints
    candidates = 
      available
      |> Enum.reject(&(&1 in selected))
      |> filter_by_constraints(selected, remaining, constraints)
    
    if Enum.empty?(candidates) do
      # Retry with different pool
      do_generate_with_constraints(pools, weights, selected, remaining, constraints)
    else
      number = Enum.random(candidates)
      do_generate_with_constraints(
        pools,
        weights,
        [number | selected],
        remaining - 1,
        update_constraints(constraints, number)
      )
    end
  end
  
  defp filter_by_constraints(candidates, selected, remaining, constraints) do
    Enum.filter(candidates, fn num ->
      even_ok? = constraints.even == 0 || rem(num, 2) == 0
      odd_ok? = constraints.odd == 0 || rem(num, 2) == 1
      low_ok? = constraints.low == 0 || num <= 25
      high_ok? = constraints.high == 0 || num > 25
      
      (even_ok? || odd_ok?) && (low_ok? || high_ok?)
    end)
  end
  
  defp weighted_random_pool(weights) do
    rand = :rand.uniform()
    
    Enum.reduce_while(weights, 0, fn {pool, weight}, acc ->
      new_acc = acc + weight
      if rand <= new_acc do
        {:halt, pool}
      else
        {:cont, new_acc}
      end
    end)
  end
  
  ## Euro Numbers (2 from 1-12)
  
  defp generate_euro_numbers(rules) do
    pools = build_euro_pools(rules)
    [even_count, odd_count] = rules.ratio_even_odd
    
    generate_euro_with_constraints(pools, rules.weights, 2, %{
      even: even_count,
      odd: odd_count
    })
  end
  
  defp build_euro_pools(rules) do
    all_numbers = MapSet.new(1..12)
    preferred_set = MapSet.new(rules.preferred || [])
    random_set = MapSet.difference(all_numbers, preferred_set)
    
    %{
      hot: MapSet.to_list(preferred_set),
      random: MapSet.to_list(random_set)
    }
  end
  
  # Similar logic for euro numbers...
end
```

### 6.3 Simulation Runner

**Location:** `lib/numbers_evolution/simulations/runner.ex`

```elixir
defmodule NumbersEvolution.Simulations.Runner do
  use GenServer
  require Logger
  
  alias NumbersEvolution.{Simulations, Strategies}
  alias NumbersEvolution.Strategies.Generator
  
  @max_attempts 1_000_000
  @timeout_ms 300_000  # 5 minutes
  @progress_interval 10_000  # Report every 10k attempts
  
  ## Client API
  
  @spec run_async(Simulation.t(), Strategy.t(), Draw.t(), keyword()) :: :ok
  def run_async(simulation, strategy, target_draw, opts \\ []) do
    Task.start(fn ->
      result = run_simulation(strategy, target_draw, opts)
      handle_result(simulation.id, result)
    end)
    
    :ok
  end
  
  ## Implementation
  
  defp run_simulation(strategy, target_draw, opts) do
    max_attempts = Keyword.get(opts, :max_attempts, @max_attempts)
    timeout_ms = Keyword.get(opts, :timeout_seconds, 300) * 1000
    
    state = %{
      strategy: strategy,
      target: target_draw,
      attempts: 0,
      max_attempts: max_attempts,
      start_time: System.monotonic_time(:millisecond),
      timeout_ms: timeout_ms
    }
    
    do_run_simulation(state)
  end
  
  defp do_run_simulation(state) do
    cond do
      state.attempts >= state.max_attempts ->
        {:timeout, :max_attempts, state.attempts}
        
      timeout?(state) ->
        {:timeout, :time_limit, state.attempts}
        
      true ->
        run_single_attempt(state)
    end
  end
  
  defp run_single_attempt(state) do
    {:ok, numbers} = Generator.generate_numbers(state.strategy)
    new_attempts = state.attempts + 1
    
    # Broadcast progress periodically
    if rem(new_attempts, @progress_interval) == 0 do
      broadcast_progress(state, new_attempts)
    end
    
    if match_grade_1?(numbers, state.target) do
      elapsed = System.monotonic_time(:millisecond) - state.start_time
      
      {:success, %{
        matched_main: numbers.main,
        matched_euro: numbers.euro,
        attempts_count: new_attempts,
        duration_ms: elapsed,
        final_draw: %{
          main_numbers: numbers.main,
          euro_numbers: numbers.euro
        }
      }}
    else
      do_run_simulation(%{state | attempts: new_attempts})
    end
  end
  
  defp match_grade_1?(numbers, target) do
    main_match = MapSet.new(numbers.main) == MapSet.new(target.numbers.main_numbers)
    euro_match = MapSet.new(numbers.euro) == MapSet.new(target.numbers.euro_numbers)
    
    main_match && euro_match
  end
  
  defp timeout?(state) do
    elapsed = System.monotonic_time(:millisecond) - state.start_time
    elapsed >= state.timeout_ms
  end
  
  defp handle_result(simulation_id, result) do
    case result do
      {:success, data} ->
        Simulations.complete_simulation(simulation_id, "success", %{
          attempts_count: data.attempts_count,
          duration_seconds: data.duration_ms / 1000,
          result: data
        })
        
      {:timeout, reason, attempts} ->
        Simulations.complete_simulation(simulation_id, "timeout", %{
          attempts_count: attempts,
          result: %{
            reason: "timeout",
            limit_reached: Atom.to_string(reason)
          }
        })
    end
  end
  
  defp broadcast_progress(state, attempts) do
    Phoenix.PubSub.broadcast(
      NumbersEvolution.PubSub,
      "simulation:#{state.simulation_id}",
      {:simulation_progress, %{attempts: attempts}}
    )
  end
end
```

---

## 7. Authentication & Authorization

### 7.1 API Auth Plug

**Location:** `lib/numbers_evolution_web/plugs/api_auth.ex`

```elixir
defmodule NumbersEvolutionWeb.Plugs.APIAuth do
  import Plug.Conn
  import Phoenix.Controller
  
  alias NumbersEvolution.Accounts
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Accounts.verify_user_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(json: NumbersEvolutionWeb.ErrorJSON)
        |> render(:unauthorized)
        |> halt()
    end
  end
end
```

### 7.2 Rate Limiter Plug

**Location:** `lib/numbers_evolution_web/plugs/rate_limiter.ex`

```elixir
defmodule NumbersEvolutionWeb.Plugs.RateLimiter do
  import Plug.Conn
  import Phoenix.Controller
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    rate_limit_config = conn.private[:rate_limit]
    
    if rate_limit_config do
      apply_rate_limit(conn, rate_limit_config)
    else
      conn
    end
  end
  
  defp apply_rate_limit(conn, config) do
    user_id = conn.assigns.current_user.id
    scope = config[:scope]
    limit = config[:limit]
    window = config[:window]
    
    key = "rate_limit:#{scope}:#{user_id}"
    
    case check_and_increment(key, limit, window) do
      {:ok, remaining} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
        |> put_resp_header("x-ratelimit-reset", to_string(reset_time(window)))
        
      {:error, retry_after} ->
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", to_string(retry_after))
        |> json(%{
          error: "Rate limit exceeded",
          retry_after: retry_after,
          limit: %{
            max: limit,
            remaining: 0,
            reset_at: reset_datetime(window)
          }
        })
        |> halt()
    end
  end
  
  defp check_and_increment(key, limit, window) do
    # Use ETS or Redis for rate limiting
    # Simple implementation with ETS:
    case :ets.lookup(:rate_limiter, key) do
      [{^key, count, timestamp}] ->
        if System.system_time(:second) - timestamp > window do
          # Window expired, reset
          :ets.insert(:rate_limiter, {key, 1, System.system_time(:second)})
          {:ok, limit - 1}
        else
          if count < limit do
            :ets.update_counter(:rate_limiter, key, {2, 1})
            {:ok, limit - count - 1}
          else
            retry_after = window - (System.system_time(:second) - timestamp)
            {:error, retry_after}
          end
        end
        
      [] ->
        :ets.insert(:rate_limiter, {key, 1, System.system_time(:second)})
        {:ok, limit - 1}
    end
  end
  
  defp reset_time(window) do
    System.system_time(:second) + window
  end
  
  defp reset_datetime(window) do
    DateTime.utc_now()
    |> DateTime.add(window, :second)
    |> DateTime.to_iso8601()
  end
end
```

---

## 8. Implementation Steps

### Phase 1: Foundation (Week 1)

**Step 1: Project Setup**
1. Generate Phoenix project: `mix phx.new numbers_evolution --no-html --binary-id`
2. Configure database in `config/dev.exs`
3. Run: `mix ecto.create`

**Step 2: Authentication**
4. Generate auth: `mix phx.gen.auth Accounts User users`
5. Add password strength validation to User schema
6. Create API token generation endpoint
7. Implement APIAuth plug
8. Test registration and token generation

**Step 3: Database Schema**
9. Create migrations for: strategies, draws, simulations, events
10. Run migrations: `mix ecto.migrate`
11. Create Ecto schemas with embedded schemas
12. Add indexes as per db-plan.md

**Step 4: Seed Data**
13. Prepare 100-200 historical draws (CSV/JSON)
14. Create seed script: `priv/repo/seeds/draws.exs`
15. Create 15 template strategies
16. Run seeds: `mix run priv/repo/seeds.exs`

### Phase 2: Core Contexts (Week 2)

**Step 5: Draws Context**
1. Implement `Draws` context with public queries
2. Create `DrawJSON` view
3. Implement `DrawController` (4 endpoints)
4. Create `Draws.Analyzer` for hot/cold analysis
5. Test all draw endpoints

**Step 6: Strategies Context (Manual Only)**
6. Implement `Strategies` context with user scoping
7. Create `StrategyJSON` view
8. Implement `StrategyController` (CRUD endpoints)
9. Create `Strategies.Generator` for number generation
10. Create `Strategies.Validator` for rules validation
11. Test manual strategy CRUD

### Phase 3: Simulations (Week 5)

**Step 7: Simulation Runner**
1. Create `Simulations.Runner` GenServer
2. Implement number generation loop
3. Add timeout and max_attempts enforcement
4. Implement Grade I (5+2) matching
5. Add progress broadcasting via PubSub

**Step 8: Simulations Context**
6. Implement `Simulations` context
7. Create `SimulationJSON` view
8. Implement `SimulationController`
9. Test single simulation flow
10. Implement `PerformanceCalculator` service

**Step 9: Rankings & Coupons**
11. Create `RankingController` with performance queries
12. Create `CouponController` with generation logic
13. Test rankings and coupon generation

### Phase 4: AI Integration (Week 4 - Optional)

**Step 10: AI Service**
1. Create `Strategies.AIService`
2. Implement rate limiting (ETS table)
3. Build system and user prompts
4. Integrate with Claude/OpenAI API
5. Add error handling and fallbacks
6. Test with mock responses first
7. Test with real AI API

**Step 11: AI Endpoints**
8. Implement `POST /api/strategies/generate`
9. Implement `POST /api/strategies/mix`
10. Add rate limiting plugs
11. Log AI events to events table
12. Test rate limiting

### Phase 5: Polish & Testing (Week 6)

**Step 12: Error Handling**
1. Implement `FallbackController`
2. Standardize error responses
3. Add proper HTTP status codes
4. Test all error scenarios

**Step 13: Rate Limiting**
5. Initialize ETS table in Application
6. Test rate limiting for all endpoints
7. Add rate limit headers

**Step 14: Testing**
8. Unit tests for all contexts (80%+ coverage)
9. Controller tests for all endpoints
10. Integration tests for critical paths
11. Test user data isolation
12. Load testing for simulations

**Step 15: Documentation**
13. Add @doc to all public functions
14. Generate ExDoc documentation
15. Create API usage examples
16. Update README with API endpoints

### Phase 6: Deployment (Post-MVP)

**Step 16: Production Prep**
1. Configure production releases
2. Set up Fly.io deployment
3. Configure secrets (API keys)
4. Run migrations on production
5. Seed production data
6. Monitor and optimize

---

## 9. Testing Strategy

### 9.1 Unit Tests (ExUnit)

**Context Tests:**

```elixir
# test/numbers_evolution/strategies_test.exs
defmodule NumbersEvolution.StrategiesTest do
  use NumbersEvolution.DataCase, async: true
  
  alias NumbersEvolution.Strategies
  
  setup do
    user = user_fixture()
    %{user: user}
  end
  
  describe "list_strategies/2" do
    test "returns only user's strategies", %{user: user} do
      other_user = user_fixture()
      
      strategy1 = strategy_fixture(user)
      strategy2 = strategy_fixture(user)
      _other_strategy = strategy_fixture(other_user)
      
      strategies = Strategies.list_strategies(user)
      
      assert length(strategies) == 2
      assert Enum.all?(strategies, &(&1.user_id == user.id))
    end
  end
  
  describe "create_strategy/2" do
    test "creates strategy with valid attrs", %{user: user} do
      attrs = valid_strategy_attrs()
      
      assert {:ok, strategy} = Strategies.create_strategy(user, attrs)
      assert strategy.name == attrs.name
      assert strategy.user_id == user.id
    end
    
    test "returns error with invalid rules", %{user: user} do
      attrs = %{
        name: "Invalid",
        type: "manual",
        rules: %{
          main_numbers: %{
            weights: %{hot: 0.5, random: 0.3}  # doesn't sum to 1.0
          }
        }
      }
      
      assert {:error, changeset} = Strategies.create_strategy(user, attrs)
      assert "must sum to 1.0" in errors_on(changeset).rules
    end
  end
end
```

### 9.2 Controller Tests

```elixir
# test/numbers_evolution_web/controllers/strategy_controller_test.exs
defmodule NumbersEvolutionWeb.StrategyControllerTest do
  use NumbersEvolutionWeb.ConnCase, async: true
  
  alias NumbersEvolution.Strategies
  
  setup %{conn: conn} do
    user = user_fixture()
    token = generate_user_token(user)
    
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")
    
    %{conn: conn, user: user}
  end
  
  describe "GET /api/strategies" do
    test "returns user's strategies", %{conn: conn, user: user} do
      strategy = strategy_fixture(user)
      
      conn = get(conn, ~p"/api/strategies")
      
      assert %{"data" => [returned_strategy]} = json_response(conn, 200)
      assert returned_strategy["id"] == strategy.id
    end
    
    test "returns 401 without authentication" do
      conn = build_conn()
      conn = get(conn, ~p"/api/strategies")
      
      assert json_response(conn, 401)
    end
  end
  
  describe "POST /api/strategies" do
    test "creates strategy with valid attrs", %{conn: conn} do
      attrs = %{name: "Test", type: "manual", rules: valid_rules()}
      
      conn = post(conn, ~p"/api/strategies", strategy: attrs)
      
      assert %{"data" => strategy} = json_response(conn, 201)
      assert strategy["name"] == "Test"
    end
    
    test "returns errors with invalid attrs", %{conn: conn} do
      conn = post(conn, ~p"/api/strategies", strategy: %{})
      
      assert %{"errors" => errors} = json_response(conn, 400)
      assert Map.has_key?(errors, "name")
    end
  end
end
```

### 9.3 Integration Tests

```elixir
# test/numbers_evolution/integration/simulation_flow_test.exs
defmodule NumbersEvolution.Integration.SimulationFlowTest do
  use NumbersEvolution.DataCase
  
  test "complete simulation flow" do
    # Setup
    user = user_fixture()
    strategy = strategy_fixture(user)
    draw = draw_fixture()
    
    # Start simulation
    {:ok, simulation} = Simulations.start_simulation(user, %{
      strategy_id: strategy.id,
      target_draw_id: draw.id,
      options: %{max_attempts: 10_000, timeout_seconds: 10}
    })
    
    assert simulation.status == "pending"
    
    # Wait for completion (with timeout)
    result = wait_for_completion(simulation.id, 15_000)
    
    assert result.status in ["success", "timeout"]
    assert result.attempts_count > 0
    assert result.duration_seconds > 0
    
    # Check performance score updated
    updated_strategy = Strategies.get_strategy!(user, strategy.id)
    assert updated_strategy.performance_score != nil
  end
end
```

---

## 10. Security Checklist

### Pre-Deployment Verification

- [ ] All Context functions enforce user scoping
- [ ] Test coverage for data isolation (User A cannot access User B's data)
- [ ] Password strength validation (min 8 chars, 1 digit)
- [ ] Rate limiting for AI endpoints (5/day/user)
- [ ] Rate limiting for simulations (100/hour/user)
- [ ] Prompt validation (max 500 chars, sanitization)
- [ ] JSONB schema validation in all embedded schemas
- [ ] All IDs validated as UUIDs
- [ ] API tokens expire after configured period
- [ ] CSRF protection enabled for session-based requests
- [ ] HTTPS enforced in production
- [ ] API keys stored in environment variables (never in code)
- [ ] Sensitive data never logged
- [ ] SQL injection prevention via Ecto parameterized queries
- [ ] XSS prevention via Phoenix.HTML escaping
- [ ] Error messages don't leak implementation details

---

## 11. Performance Optimization

### Database

1. **Indexes** - All implemented as per db-plan.md
2. **Pagination** - All list endpoints support pagination
3. **Eager Loading** - Use `Repo.preload` to avoid N+1
4. **Query Optimization** - Use database-level aggregations

### Caching

1. **ETS for Rate Limiting** - Fast in-memory lookups
2. **Cache Hot/Cold Analysis** - 1 hour TTL
3. **Cache Rankings** - 15 minutes TTL

### Async Operations

1. **Simulations** - Run in separate Task
2. **AI Calls** - Timeout after 30 seconds
3. **Performance Calculation** - Async after simulation

---

## 12. Monitoring & Logging

### Telemetry Events

```elixir
# Emit telemetry for key operations
:telemetry.execute(
  [:numbers_evolution, :simulation, :complete],
  %{attempts: attempts, duration_ms: duration},
  %{strategy_id: strategy_id, status: status}
)
```

### Structured Logging

```elixir
Logger.info("Simulation completed",
  simulation_id: id,
  strategy_id: strategy_id,
  attempts: attempts,
  duration: duration,
  status: status
)
```

---

## 13. Documentation

### API Documentation (OpenAPI/Swagger)

Generate interactive API docs using `open_api_spex`:

```elixir
# lib/numbers_evolution_web/api_spec.ex
defmodule NumbersEvolutionWeb.APISpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}
  
  def spec do
    %OpenApi{
      info: %Info{
        title: "Numbers Evolution API",
        version: "1.0"
      },
      servers: [
        %Server{url: "http://localhost:4000/api"}
      ],
      paths: Paths.from_router(NumbersEvolutionWeb.Router)
    }
  end
end
```

Host at `/api/docs` using Swagger UI.

---

## 14. Deployment Checklist

### Pre-Deployment

- [ ] All tests passing (`mix test`)
- [ ] No Credo warnings (`mix credo --strict`)
- [ ] Code formatted (`mix format --check-formatted`)
- [ ] Documentation complete (`mix docs`)
- [ ] Environment variables documented in README
- [ ] Database migrations tested
- [ ] Seed data prepared for production

### Deployment

- [ ] Create Fly.io app
- [ ] Configure secrets (API keys, SECRET_KEY_BASE)
- [ ] Deploy: `fly deploy`
- [ ] Run migrations: `fly ssh console -C "/app/bin/migrate"`
- [ ] Seed data if needed
- [ ] Verify health check endpoint
- [ ] Monitor logs for errors

---

## 15. Next Steps (Post-MVP)

1. **Multi-Simulations** (MVP2)
2. **Simulation Cancellation**
3. **Global Rankings**
4. **Email Confirmation**
5. **OAuth Integration**
6. **GraphQL API** (alternative to REST)
7. **Mobile SDKs**
8. **Advanced Analytics**

---

**Document Status:** Ready for Implementation  
**Last Updated:** November 15, 2025  
**Estimated Implementation Time:** 6 weeks (MVP1)  
**Next Action:** Begin Phase 1 - Foundation

