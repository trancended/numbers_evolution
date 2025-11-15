defmodule NumbersEvolutionWeb.Plugs.APIAuth do
  @moduledoc """
  Plug for API authentication using Bearer tokens.

  Verifies the Authorization header and loads the current user.
  """

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
        |> put_view(NumbersEvolutionWeb.ErrorJSON)
        |> render(:unauthorized)
        |> halt()
    end
  end
end
