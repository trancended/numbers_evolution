# Elixir Rules - Numbers Evolution

## Language Fundamentals
- Lists don't support index-based access - use `Enum.at/2` or pattern matching
- Variables are immutable but can be rebound
- Rebind results of block expressions (`if`, `case`, `cond`) to variables
- Never nest multiple modules in the same file (causes cyclic dependencies)
- Never use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names end with `?`, don't use `is_` prefix
- Never use map access syntax (`map[:key]`) on structs - use `struct.field` directly

## Ecto Schema & Queries
- Preload associations in queries when used in templates
- Import `Ecto.Query` in seed files and contexts
- Schema fields use `:string` type even for `:text` columns
- `validate_number/2` does NOT support `:allow_nil` option
- Use `Ecto.Changeset.get_field/2` to access changeset fields
- Never add programmatically set fields (e.g., `user_id`) to `cast/3`
- Always scope queries by `user_id` for data isolation
- Use JSONB for flexible schema fields (strategy `rules`, simulation `result`)
- Index JSONB fields for efficient queries

## Project-Specific Schema
- Core tables: `users`, `strategies`, `draws`, `simulations`
- Strategy types: `:manual`, `:ai_generated`
- Simulation statuses: `:success`, `:timeout`, `:error`
- Game types: `:eurojackpot` (extensible for future games)
- UUIDs as primary keys
- Use default Ecto timestamps: `inserted_at`, `updated_at`

## Phoenix Framework
- Router scopes include optional alias - avoid duplicating prefixes
- Never use `Phoenix.View` (deprecated, not needed in Phoenix 1.8+)
- Use `to_form/2` for forms in LiveView
- Always preload Ecto associations used in views
- Context pattern for business logic separation
- Avoid `/dashboard` route (reserved in Phoenix)

## Phoenix Authentication
- Use `mix phx.gen.auth` for authentication setup
- Bcrypt for password hashing
- CSRF protection automatic (Phoenix tokens)
- Secure session cookies (HttpOnly, Secure flags)
- Scope all queries by `user_id` for isolation
- MVP1: simple email/password, no OAuth, no email confirmation, no password reset

## LiveView Architecture
- Single Page Application on `/` route
- Name LiveViews with `Live` suffix (e.g., `DashboardLive`)
- Use `<.link navigate={}>` and `<.link patch={}>` instead of deprecated functions
- Avoid LiveComponent unless strong specific need
- Use `phx-update="ignore"` with `phx-hook` for JS-managed DOM
- Never write embedded `<script>` tags in HEEx
- Real-time updates via LiveView messaging (e.g., simulation progress every 2s)

## LiveView Streams
- Use streams for collections to prevent memory bloating
- Set `phx-update="stream"` on parent element
- Access via `@streams.stream_name` in templates
- Streams are NOT enumerable - refetch and use `reset: true` for filtering
- Track count and empty states with separate assigns
- Never use deprecated `phx-update="append"` or `prepend`

## Forms in LiveView
- Use `Phoenix.Component.form/1` and `to_form/2`
- Never use deprecated `Phoenix.HTML.form_for`
- Assign form via `to_form/2` in LiveView module
- Access fields via `@form[:field]` in templates
- Add unique DOM IDs to forms for testing (e.g., `id="strategy-form"`)
- Validation errors displayed via LiveView changeset errors
- Always validate at save time, not before use

## HEEx Templates
- Use `~H` or `.html.heex` files - never `~E`
- Interpolation in attributes: `{...}`, in body: `{...}` or `<%= ... %>`
- Block constructs (if, for, cond) in body: `<%= ... %>`
- No `else if` - use `cond` or `case` for multiple conditionals
- Comments: `<%!-- comment --%>`
- Use `phx-no-curly-interpolation` for literal `{` and `}`
- Classes as list `[...]` for conditional values
- Never use `Enum.each` for rendering - use `<%= for item <- @collection do %>`
- Always wrap `if` expressions in `{...}` with parens: `if(@condition, do: "class", else: "other")`

## Concurrency & Tasks
- Use `Task.async` for simulations (long-running processes)
- Pass `timeout: :infinity` for operations that may exceed 5 seconds
- Simulations continue in background even after browser disconnection
- Proper timeout handling (default 300 seconds for simulations)
- Max attempts limit (default 1 million for simulations)
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure
- Name OTP processes in child spec: `{DynamicSupervisor, name: NumbersEvolution.Sup}`

## AI Integration
- Use `:req` library for HTTP requests to AI APIs
- Preferred: Claude 3.5 Sonnet (2.5x cheaper than GPT-4 Turbo)
- Alternative: OpenAI GPT-4 Turbo
- Structured prompts including:
  - Last 32 historical draws
  - Hot/cold number analysis
  - User's previous strategy performance
  - Strategic guidelines
  - User prompt
- Expect JSON response with validation
- Handle errors gracefully: display to user with retry option
- No automatic fallback to random strategy on AI failure
- Rate limiting: 5 AI generations per user per day (post-MVP)
- Prompt validation: max 500 characters (security)

## Strategy Logic
- Strategy rules stored as JSONB
- Rules include: weights, ratios (even/odd, low/high), preferred numbers
- Weights must sum to 1.0 (validation at save)
- Strategy can be :manual or :ai_generated
- Mixes created as new strategies (no separate table)
- Conflict resolution: higher performance_score takes priority
- Performance score = median of attempts_count from simulations

## Simulation Engine
- Generate number sets in loop according to strategy rules
- Compare with target draw (checking for 5+2 match)
- Track ONLY primary win (5+2) in MVP1
- Status: :success (matched 5+2), :timeout (limit reached), :error
- Save result to simulations table with attempts_count, duration_seconds
- Send progress updates to LiveView every 2 seconds

## Testing Strategy
- Unit tests: ExUnit for business logic
- Focus areas: number generation, comparison, median calculation, validations
- NO integration tests for LiveView or AI API in MVP1
- Manual testing for LiveView UI
- Manual testing for AI integration with real API calls
- CI/CD: GitHub Actions runs tests on every push/PR
- Use `Phoenix.LiveViewTest` for form testing
- Use `LazyHTML` for HTML assertions
- Reference element IDs from templates in tests
- Never test raw HTML - use `element/2`, `has_element/2`
- Test outcomes, not implementation details

## Date & Time
- Use built-in modules: `Time`, `Date`, `DateTime`, `Calendar`
- Install additional dependencies only for parsing (e.g., `date_time_parser`)
- Historical draws seeded with draw_date (date type)

## HTTP Requests
- Use `:req` (Req) library for HTTP requests
- Avoid `:httpoison`, `:tesla`, `:httpc`
- Req is included by default and preferred for Phoenix apps

## Security Considerations
- All queries scoped by user_id for data isolation
- Prevent SQL injection via Ecto parameterized queries
- XSS prevention via Phoenix.HTML auto-escaping
- CSRF protection automatic
- API keys in environment variables (never committed)
- Rate limiting for AI requests (post-MVP)
- Prompt validation to prevent injection attacks
- No sensitive data in logs (especially API keys)

## Performance Optimization
- Use indexes on frequently queried fields (user_id, strategy_id, draw_date)
- JSONB indexed queries for strategy rules
- Connection pooling for database
- Consider partitioning simulations table if grows large (post-MVP)
- No caching of AI responses in MVP1
- No rate limiting in MVP1 (add post-MVP if costs become issue)

## Code Organization
- Context pattern for business logic (Strategies, Simulations, Draws)
- Separate concerns: contexts handle data, LiveViews handle UI
- Keep LiveViews thin - delegate to contexts
- DRY principles - extract reusable functions
- Clear function names describing intent
- Document complex business logic
- Use mix aliases: `mix precommit` before committing changes

## Error Handling
- Pattern match on results: `{:ok, result}` / `{:error, reason}`
- Use `case` for handling multiple outcomes
- Display user-friendly error messages in UI
- Log technical errors for debugging
- Graceful degradation when AI fails
- Timeout handling for long-running processes
- Never let processes run indefinitely

## Database Seeding
- Seed 100-200 historical Eurojackpot draws
- Data prepared manually (publicly available)
- Update weekly via manual seeding/migrations
- No admin panel in MVP1
- Future: consider scraping or API integration

## Monitoring & Analytics
- Basic event logging to database (events table)
- Track: strategy_created, simulation_started, coupons_generated
- Simple analytics via SQL queries
- No external tools (Google Analytics, Mixpanel) in MVP1
- Monitor simulation success rates and timeouts
- Track AI API failures and costs

