defmodule NumbersEvolution.Accounts do
  @moduledoc """
  The Accounts context.

  Handles user authentication, registration, and profile management.
  """

  import Ecto.Query, warn: false
  alias NumbersEvolution.Accounts.{User, UserToken}
  alias NumbersEvolution.Repo

  ## User Registration

  @doc """
  Registers a new user.

  ## Examples

      iex> register_user(%{email: "user@example.com", password: "password123"})
      {:ok, %User{}}

      iex> register_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  ## User Authentication

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("user@example.com", "password123")
      {:ok, %User{}}

      iex> get_user_by_email_and_password("user@example.com", "wrong")
      {:error, :invalid_credentials}

  """
  @spec get_user_by_email_and_password(String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :invalid_credentials}
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)

    if User.valid_password?(user, password) do
      {:ok, user}
    else
      # Help prevent timing attacks
      Bcrypt.no_user_verify()
      {:error, :invalid_credentials}
    end
  end

  @doc """
  Generates a session token for the user.
  """
  @spec generate_user_session_token(User.t()) :: String.t()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Verifies a user token and returns the user.
  """
  @spec verify_user_token(String.t()) :: {:ok, User.t()} | {:error, :invalid}
  def verify_user_token(token) do
    with {:ok, query} <- UserToken.verify_session_token_query(token),
         %User{} = user <- Repo.one(query) do
      {:ok, user}
    else
      _ -> {:error, :invalid}
    end
  end

  @doc """
  Deletes a session token.
  """
  @spec delete_user_session_token(String.t()) :: :ok
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## User Management

  @doc """
  Gets a user by ID.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!("c6a7b042-...")
      %User{}

      iex> get_user!("invalid-uuid")
      ** (Ecto.NoResultsError)

  """
  @spec get_user!(binary()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("user@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Lists all users in the system.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  @spec list_users() :: [User.t()]
  def list_users do
    Repo.all(User)
  end

  @doc """
  Updates user preferences.

  ## Examples

      iex> update_user_preferences(user, %{theme: "dark"})
      {:ok, %User{}}

      iex> update_user_preferences(user, %{invalid: "data"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_user_preferences(User.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user_preferences(%User{} = user, preferences) do
    user
    |> User.preferences_changeset(preferences)
    |> Repo.update()
  end

  @doc """
  Changes the user password.

  ## Examples

      iex> change_user_password(user, "current_password", %{password: "new_password"})
      {:ok, %User{}}

      iex> change_user_password(user, "wrong_password", %{password: "new_password"})
      {:error, %Ecto.Changeset{}}

  """
  @dialyzer {:nowarn_function, change_user_password: 3}
  @spec change_user_password(User.t(), String.t(), map()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def change_user_password(user, current_password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(current_password)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:user, fn _repo, _changes ->
      case Repo.update(changeset) do
        {:ok, user} -> {:ok, user}
        {:error, changeset} -> {:error, changeset}
      end
    end)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_query(user))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## User Statistics

  @doc """
  Gets user statistics including strategies count, simulations count, and best strategy.

  ## Examples

      iex> get_user_stats(user)
      %{
        strategies_count: 5,
        simulations_count: 42,
        best_strategy: %{id: "...", name: "...", performance_score: 0.85}
      }

  """
  @spec get_user_stats(User.t()) :: map()
  def get_user_stats(%User{id: user_id}) do
    %{
      strategies_count: count_user_strategies(user_id),
      simulations_count: count_user_simulations(user_id),
      best_strategy: get_user_best_strategy(user_id)
    }
  end

  defp count_user_strategies(user_id) do
    from(s in NumbersEvolution.Strategies.Strategy,
      where: s.user_id == ^user_id and s.status == "active"
    )
    |> Repo.aggregate(:count)
  end

  defp count_user_simulations(user_id) do
    from(s in NumbersEvolution.Simulations.Simulation,
      where: s.user_id == ^user_id
    )
    |> Repo.aggregate(:count)
  end

  defp get_user_best_strategy(user_id) do
    from(s in NumbersEvolution.Strategies.Strategy,
      where: s.user_id == ^user_id and s.status == "active",
      where: not is_nil(s.performance_score),
      order_by: [desc: s.performance_score],
      limit: 1,
      select: %{id: s.id, name: s.name, performance_score: s.performance_score}
    )
    |> Repo.one()
  end
end
