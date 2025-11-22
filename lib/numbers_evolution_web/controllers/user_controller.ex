defmodule NumbersEvolutionWeb.UserController do
  @moduledoc """
  Controller for user authentication and profile management.
  """

  use NumbersEvolutionWeb, :controller

  alias NumbersEvolution.Accounts

  action_fallback(NumbersEvolutionWeb.FallbackController)

  # POST /api/users/register
  def register(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        token = Accounts.generate_user_session_token(user)

        conn
        |> put_status(:created)
        |> render(:show_with_token, user: user, token: token)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  # POST /api/auth/token
  def create_token(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      {:ok, user} ->
        token = Accounts.generate_user_session_token(user)

        conn
        |> put_status(:ok)
        |> render(:token, token: token)

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> put_view(NumbersEvolutionWeb.ErrorJSON)
        |> render(:error, message: "Invalid email or password")
    end
  end

  # GET /api/users/me
  def show(conn, _params) do
    user = conn.assigns.current_user
    stats = Accounts.get_user_stats(user)

    conn
    |> put_status(:ok)
    |> render(:show_with_stats, user: user, stats: stats)
  end

  # PATCH /api/users/me
  def update(conn, %{"user" => user_params}) do
    user = conn.assigns.current_user

    case Accounts.update_user_preferences(user, user_params["preferences"] || %{}) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> render(:show, user: updated_user)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  # POST /api/users/me/password
  def change_password(
        conn,
        %{
          "current_password" => current_password,
          "password" => _password,
          "password_confirmation" => _confirmation
        } = params
      ) do
    user = conn.assigns.current_user

    case Accounts.change_user_password(user, current_password, params) do
      {:ok, _updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Password updated successfully"})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  def change_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, message: "Missing required password fields")
  end
end
