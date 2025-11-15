defmodule NumbersEvolutionWeb.DrawJSON do
  @moduledoc """
  JSON rendering for Draw resources.
  """

  alias NumbersEvolution.Draws.Draw

  @doc """
  Renders a list of draws.
  """
  def index(%{draws: draws, meta: meta}) do
    %{
      data: for(draw <- draws, do: data(draw)),
      meta: meta
    }
  end

  @doc """
  Renders a single draw.
  """
  def show(%{draw: draw}) do
    %{data: data(draw)}
  end

  @doc """
  Renders draw analysis (hot/cold numbers).
  """
  def analysis(%{analysis: analysis, game_type: game_type, period: period}) do
    %{
      data: %{
        game_type: game_type,
        analyzed_draws: period,
        main_numbers: %{
          hot: analysis.main_numbers.hot,
          cold: analysis.main_numbers.cold,
          frequencies: analysis.main_numbers.frequencies
        },
        euro_numbers: %{
          hot: analysis.euro_numbers.hot,
          cold: analysis.euro_numbers.cold,
          frequencies: analysis.euro_numbers.frequencies
        }
      }
    }
  end

  defp data(%Draw{} = draw) do
    %{
      id: draw.id,
      draw_date: draw.draw_date,
      game_type: draw.game_type,
      numbers: render_numbers(draw.numbers),
      source: draw.source,
      inserted_at: draw.inserted_at
    }
  end

  defp render_numbers(nil), do: nil

  defp render_numbers(numbers) do
    %{
      main_numbers: numbers.main_numbers,
      euro_numbers: numbers.euro_numbers
    }
  end
end
