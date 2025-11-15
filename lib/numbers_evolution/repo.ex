defmodule NumbersEvolution.Repo do
  use Ecto.Repo,
    otp_app: :numbers_evolution,
    adapter: Ecto.Adapters.Postgres
end
