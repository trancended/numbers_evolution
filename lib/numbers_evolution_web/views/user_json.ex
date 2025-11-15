defmodule NumbersEvolutionWeb.UserJSON do
  @moduledoc """
  JSON rendering for User resources (Phoenix 1.8 style).
  """

  alias NumbersEvolution.Accounts.User

  @doc """
  Renders a single user.
  """
  def show(%{user: user}) do
    %{data: data(user)}
  end

  @doc """
  Renders a user with statistics.
  """
  def show_with_stats(%{user: user, stats: stats}) do
    %{
      data:
        user
        |> data()
        |> Map.merge(%{
          strategies_count: stats.strategies_count,
          simulations_count: stats.simulations_count,
          best_strategy: stats.best_strategy
        })
    }
  end

  @doc """
  Renders a user with token (for registration).
  """
  def show_with_token(%{user: user, token: token}) do
    %{
      data: data(user),
      token: token
    }
  end

  @doc """
  Renders a session token.
  """
  def token(%{token: token}) do
    %{
      data: %{
        token: token,
        token_type: "Bearer"
      }
    }
  end

  defp data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      preferences: user.preferences || %{},
      confirmed_at: user.confirmed_at,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
end
