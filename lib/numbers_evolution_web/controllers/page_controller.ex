defmodule NumbersEvolutionWeb.PageController do
  use NumbersEvolutionWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
