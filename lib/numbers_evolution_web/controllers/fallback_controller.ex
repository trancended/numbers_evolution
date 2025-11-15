defmodule NumbersEvolutionWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use NumbersEvolutionWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:bad_request)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:not_found)
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:unauthorized)
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:forbidden)
  end

  def call(conn, {:error, :strategy_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, message: "Strategy not found")
  end

  def call(conn, {:error, :draw_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, message: "Draw not found")
  end

  def call(conn, {:error, :invalid_strategy_id}) do
    conn
    |> put_status(:bad_request)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, message: "Invalid strategy ID")
  end

  def call(conn, {:error, :invalid_draw_id}) do
    conn
    |> put_status(:bad_request)
    |> put_view(NumbersEvolutionWeb.ErrorJSON)
    |> render(:error, message: "Invalid draw ID")
  end
end
