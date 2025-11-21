defmodule NumbersEvolutionWeb.Router do
  use NumbersEvolutionWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug NumbersEvolutionWeb.Plugs.SaveSession
    plug :put_root_layout, html: {NumbersEvolutionWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug NumbersEvolutionWeb.Plugs.APIAuth
    plug NumbersEvolutionWeb.Plugs.RateLimiter
  end

  scope "/", NumbersEvolutionWeb do
    pipe_through :browser

    live "/", PageLive, :index
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

    # E2E test helpers (only in test_e2e environment)
    if Mix.env() == :test_e2e do
      post "/e2e/reset-db", E2eController, :reset_db
    end
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

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:numbers_evolution, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NumbersEvolutionWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
