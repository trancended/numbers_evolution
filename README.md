# Numbers Evolution

### 🌐 Languages

[English](README.md) | [Polski](README.pl.md)

[![Project Status](https://img.shields.io/badge/status-in%20development-yellow)](https://github.com)
[![Tech Stack](https://img.shields.io/badge/Elixir-4B275F?logo=elixir&logoColor=white)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-FD4F00?logo=phoenixframework&logoColor=white)](https://www.phoenixframework.org/)
[![LiveView](https://img.shields.io/badge/LiveView-real--time-brightgreen)](https://hexdocs.pm/phoenix_live_view/)

> An educational web application for testing and analyzing number picking strategies in Eurojackpot with AI-powered insights

## 📋 Table of Contents

- [About](#about)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Available Scripts](#available-scripts)
- [Project Scope](#project-scope)
- [Project Status](#project-status)
- [Architecture](#architecture)
- [Security](#security)
- [License](#license)

## 🎯 About

Numbers Evolution is an educational web application that enables users to test and analyze various number picking strategies for the Eurojackpot lottery game. Built as a course project for 10xdevs, it demonstrates the capabilities of Phoenix LiveView, AI integration, and concurrent programming in Elixir.

### Key Features

- **Strategy Management**: Create, edit, and manage number picking strategies manually or with AI assistance
- **AI-Powered Generation**: Generate strategies using natural language prompts (OpenAI GPT-4 Turbo or Claude 3.5 Sonnet)
- **Real-time Simulations**: Run simulations on historical lottery data with live progress tracking
- **Performance Analytics**: Compare strategy effectiveness using statistical analysis
- **Ticket Generator**: Generate number proposals for upcoming draws based on top-performing strategies
- **Multi-simulations**: Run parallel simulations across multiple historical draws (MVP2)

### Target Personas

- **Data Analyst Tom**: Statistics enthusiast who wants to experiment with different strategy parameters and discover patterns
- **Player Mark**: Regular Eurojackpot player who wants to test strategies without spending money on tickets

### Educational Disclaimer

⚠️ **This application is for educational and simulation purposes only.** It does not guarantee lottery wins and is not officially affiliated with lottery operators. Use at your own discretion.

## 🛠 Tech Stack

### Core Technologies

- **Backend**: [Elixir](https://elixir-lang.org/) with [Phoenix Framework](https://www.phoenixframework.org/)
- **Frontend**: [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/) (real-time SPA)
- **Database**: [PostgreSQL](https://www.postgresql.org/) with JSONB support
- **AI Provider**: [OpenAI GPT-4 Turbo](https://openai.com/) or [Claude 3.5 Sonnet](https://www.anthropic.com/)
- **Authentication**: Phoenix `phx.gen.auth`
- **Deployment**: [Fly.io](https://fly.io/) (post-MVP)

### Key Libraries & Tools

- **Ecto**: Database wrapper and query generator
- **Task.async**: Concurrent simulation execution
- **Phoenix PubSub**: Real-time messaging for live tracking
- **Jason**: JSON encoding/decoding
- **Bcrypt**: Secure password hashing

### Why This Stack?

- **Phoenix LiveView**: Provides real-time updates without complex WebSocket implementation
- **Elixir Concurrency**: Perfect for running multiple simulations in parallel using lightweight processes
- **BEAM VM**: Built-in fault tolerance and excellent scalability
- **PostgreSQL JSONB**: Flexible schema for dynamic strategy rules

## 🚀 Getting Started

### Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- PostgreSQL 14+
- Node.js 16+ (for asset compilation)
- An OpenAI or Anthropic API key (for AI features)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/numbers_evolution.git
   cd numbers_evolution
   ```

2. **Install dependencies**
   ```bash
   mix deps.get
   mix deps.compile
   ```

3. **Install Node.js dependencies**
   ```bash
   cd assets && npm install && cd ..
   ```

4. **Set up environment variables**
   
   Create a `.env` file or export the following:
   ```bash
   export DATABASE_URL="postgresql://user:password@localhost/numbers_evolution_dev"
   export OPENAI_API_KEY="your_openai_api_key"
   # OR
   export CLAUDE_API_KEY="your_claude_api_key"
   export SECRET_KEY_BASE="generate_with_mix_phx_gen_secret"
   ```

5. **Create and migrate the database**
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

6. **Seed historical lottery data**
   ```bash
   mix run priv/repo/seeds.exs
   ```

7. **Start the Phoenix server**
   ```bash
   mix phx.server
   ```

8. **Visit the application**
   
   Navigate to [`localhost:4000`](http://localhost:4000) in your browser.

### Docker Setup (Alternative)

```bash
docker-compose up -d
mix ecto.create
mix ecto.migrate
mix phx.server
```

## 📜 Available Scripts

### Development

- `mix phx.server` - Start the Phoenix server
- `mix phx.server --no-halt` - Start the server in production mode
- `iex -S mix phx.server` - Start the server with interactive Elixir shell

### Database

- `mix ecto.create` - Create the database
- `mix ecto.migrate` - Run database migrations
- `mix ecto.rollback` - Rollback the last migration
- `mix ecto.reset` - Drop, create, and migrate the database
- `mix run priv/repo/seeds.exs` - Seed the database with historical lottery data

### Testing

- `mix test` - Run all tests
- `mix test --cover` - Run tests with coverage report
- `mix test test/path/to/test.exs` - Run a specific test file

### E2E Testing

**Important:** E2E tests require the server to run in `test_e2e` environment.

1. **Setup E2E database:**
   ```bash
   MIX_ENV=test_e2e mix ecto.create
   MIX_ENV=test_e2e mix ecto.migrate
   ```

2. **Start server in test_e2e environment:**
   ```bash
   MIX_ENV=test_e2e mix phx.server
   ```

3. **Run Cypress tests (in separate terminal):**
   ```bash
   npm run cypress:run
   ```

   Or use the all-in-one command:
   ```bash
   npm run e2e:test
   ```

See `cypress/README.md` for detailed E2E testing instructions.

### Code Quality

- `mix format` - Format code according to Elixir style guide
- `mix credo` - Run static code analysis
- `mix dialyzer` - Run type checking (requires initial setup)

### Authentication

- `mix phx.gen.auth Accounts User users` - Generate authentication system (already done)

### Production

- `mix phx.digest` - Compile and digest assets for production
- `MIX_ENV=prod mix release` - Build a production release

## 📦 Project Scope

### MVP1 Features (6 weeks)

#### ✅ User Authorization (F7)
- User registration and login (email + password)
- Session management with secure cookies
- Password change functionality
- Data isolation per user

#### ✅ Strategy Management (F1)
- Full CRUD operations for strategies
- Manual strategy creation with parameters:
  - Even/odd ratio for main numbers
  - Low/high ratio (1-25 vs 26-50)
  - Hot/cold number preferences
  - Weighted criteria
- AI-powered strategy generation via natural language prompts
- Strategy validation (weights sum to 1.0, valid ratios)
- Strategy mixing (combine 2-3 strategies into hybrids)

#### ✅ Historical Data (F6)
- 100-200 historical Eurojackpot draws seeded
- Universal data structure for future game types
- Manual updates via migrations (weekly)

#### ✅ Simulation Engine (F2)
- Single simulation execution on historical draws
- Safety limits:
  - Default timeout: 300 seconds
  - Default max attempts: 1,000,000
- Background execution with `Task.async`
- Win detection: 5 main numbers + 2 euro numbers (5+2)

#### ✅ Live Tracking (F3)
- Real-time progress updates every 2 seconds
- LiveView messaging for seamless updates
- Display: attempt counter, duration, status
- Simulations continue even if browser is closed

#### ✅ Ranking & Analytics (F4)
- Performance score calculation (median attempts)
- Strategy ranking by effectiveness
- Simulation history with filtering
- Mix ranking after multisimulations

#### ✅ Ticket Generator (F5)
- Identify top 3 performing strategies
- Generate 1-10 unique ticket proposals
- Visual "ball" display for numbers
- Regeneration capability

#### ✅ Dashboard (F8)
- Single-page application (SPA) experience
- User statistics overview
- Quick actions for common tasks
- Section-based navigation without page reloads

### MVP2 Features (Enhanced)

#### 🔄 Multisimulations (F-MS)
- Run 3-10 parallel simulations simultaneously
- Each simulation on different historical draws
- Aggregate statistics and analysis
- Live tracking of all parallel processes

### Out of Scope (MVP1)

- ❌ Additional lottery games (Multi Multi, Lotto, Keno)
- ❌ Advanced evolutionary algorithms
- ❌ Stop button for running simulations
- ❌ Tracking all prize tiers (only 5+2 in MVP1)
- ❌ Advanced visualizations (charts, heatmaps)
- ❌ Automated lottery data imports
- ❌ Public API
- ❌ Social features (sharing strategies)
- ❌ Mobile apps (iOS/Android) - responsive web only
- ❌ Export to PDF/Excel
- ❌ Email/push notifications
- ❌ Machine learning predictions
- ❌ Admin panel UI

## 📊 Project Status

### Current Phase: Development

**Timeline**: 6-week MVP1 development cycle

#### Week 1-2: Foundation ✅
- [x] Project setup and configuration
- [x] Database schema and migrations
- [x] Authentication system (phx.gen.auth)
- [x] Basic layout and navigation
- [x] Historical lottery data seeding

#### Week 3: Strategy Module 🔄
- [ ] Strategy CRUD operations
- [ ] Manual strategy form
- [ ] Template strategies (15 presets)
- [ ] Strategy validation logic

#### Week 4: AI Integration 🔜
- [ ] AI service module
- [ ] Prompt engineering for strategy generation
- [ ] JSON response parsing and validation
- [ ] Error handling and fallbacks
- [ ] Rate limiting (5 generations/user/day)

#### Week 5: Simulation Engine 🔜
- [ ] Core simulation algorithm
- [ ] Task.async implementation
- [ ] Timeout and limit enforcement
- [ ] Result persistence
- [ ] Live tracking integration

#### Week 6: Final Features 🔜
- [ ] Ranking system
- [ ] Performance score calculation
- [ ] Ticket generator
- [ ] Dashboard polish
- [ ] Testing and documentation

#### Post-MVP1
- [ ] Fly.io deployment
- [ ] Multisimulations (MVP2)
- [ ] Email confirmation
- [ ] OAuth integration (optional)

### Success Metrics

**Functional Success**:
- ✅ User can register, login, and manage account
- ✅ User can perform full CRUD on strategies
- ⏳ User can create strategies manually or via AI
- ⏳ User can run single simulation on historical data
- ⏳ User can run multisimulations (MVP2)
- ⏳ Real-time progress tracking works via LiveView
- ⏳ Rankings display based on median attempts
- ⏳ Ticket generator produces valid proposals

**Performance Success**:
- Target: 50%+ simulations complete successfully within limits
- Target: Multisimulation (5 draws) completes in <2 minutes
- Target: >95% simulations without errors
- Target: All simulations respect timeout (≤300s) and attempt limits (≤1M)

**Product Success**:
- Target: >60% of strategies are AI-generated
- Target: Average >5 simulations per user in first week
- Target: >40% of users use ticket generator

## 🏗 Architecture

### Context Pattern

The application follows Phoenix's context pattern for clean separation of concerns:

```
lib/numbers_evolution/
├── accounts/          # User authentication and management
├── strategies/        # Strategy CRUD and AI generation
├── simulations/       # Simulation engine and tracking
├── draws/             # Historical lottery data
└── analytics/         # Rankings and performance metrics
```

### Database Schema

**Core Tables**:
- `users` - User accounts and authentication
- `strategies` - User-created strategies with JSONB rules
- `draws` - Historical lottery results
- `simulations` - Simulation runs and results

### Concurrency Model

- **Simulation Tasks**: Each simulation runs in an isolated `Task.async` process
- **LiveView Processes**: One process per connected user for real-time updates
- **PubSub Messaging**: Communication between simulation tasks and LiveView processes

### AI Integration Flow

1. User submits natural language prompt
2. System fetches last 32 lottery draws
3. System analyzes hot/cold numbers
4. Structured prompt sent to AI provider (OpenAI or Claude)
5. AI returns JSON with strategy parameters
6. JSON validated and parsed
7. Strategy saved to database with type: `ai_generated`

## 🔒 Security

### Implemented

- ✅ **Password Hashing**: Bcrypt with proper work factor
- ✅ **CSRF Protection**: Automatic token generation and validation
- ✅ **SQL Injection Protection**: Ecto parameterized queries
- ✅ **XSS Protection**: Phoenix.HTML automatic escaping
- ✅ **Secure Sessions**: HttpOnly and Secure cookie flags
- ✅ **Data Isolation**: All queries scoped by user_id

### Recommended Enhancements

- 🔐 **Password Strength Validation**: Min 8 chars, 1 digit, 1 special char
- 🔐 **AI Rate Limiting**: 5 generations per user per day
- 🔐 **Prompt Validation**: Max 500 character limit
- 🔐 **Email Confirmation**: Prevent spam accounts
- 🔐 **JSON Schema Validation**: Validate strategy rules structure

### Production Considerations

For production deployment with >50 users:
- Implement all recommended security enhancements
- Enable email confirmation
- Add audit logging
- Consider 2FA for sensitive accounts
- Monitor AI costs and enforce stricter rate limits

## 🤝 Contributing

This is an educational project for the 10xdevs course. Contributions are welcome after MVP1 completion.

### Development Guidelines

1. Follow Elixir style guide (use `mix format`)
2. Write tests for new features
3. Ensure all tests pass before submitting PR
4. Update documentation as needed
5. Follow Phoenix context patterns

## 📄 License

This project is open source and available under the MIT License.

## 📞 Contact

Project developed as part of [10xdevs](https://10xdevs.pl/) course.

---

**Note**: This application is purely educational and does not encourage gambling. It demonstrates Phoenix LiveView capabilities, AI integration, and Elixir concurrency patterns.

