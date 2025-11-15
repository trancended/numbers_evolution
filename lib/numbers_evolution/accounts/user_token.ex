defmodule NumbersEvolution.Accounts.UserToken do
  @moduledoc """
  Schema for user authentication tokens.

  Supports session tokens for API authentication.
  """

  use Ecto.Schema
  import Ecto.Query
  alias NumbersEvolution.Accounts.{User, UserToken}

  @hash_algorithm :sha256
  @rand_size 32

  # Session tokens expire in 60 days
  @session_validity_in_days 60

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, User, type: :binary_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token for session authentication.
  """
  @spec build_session_token(User.t()) :: {String.t(), %__MODULE__{}}
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{
       token: hashed_token,
       context: "session",
       user_id: user.id
     }}
  end

  @doc """
  Checks if the token is valid and returns a query to fetch the user.

  The token is valid if it matches the value in the database and hasn't expired.
  """
  @spec verify_session_token_query(String.t()) :: {:ok, Ecto.Query.t()} | :error
  def verify_session_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "session"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(@session_validity_in_days, "day"),
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Returns a query to fetch a token by its value and context.
  """
  @spec by_token_and_context_query(binary(), String.t()) :: Ecto.Query.t()
  def by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end

  @doc """
  Returns a query to fetch all tokens for a user.
  """
  @spec by_user_query(User.t()) :: Ecto.Query.t()
  def by_user_query(user) do
    from t in UserToken, where: t.user_id == ^user.id
  end
end
