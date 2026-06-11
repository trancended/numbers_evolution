defmodule NumbersEvolutionWeb.SharedComponents do
  @moduledoc """
  Shared formatting and helper functions for Numbers Evolution.
  Note: number_ball, status_indicator, and empty_state are in CoreComponents.
  This module only contains domain-specific formatting helpers.
  """
  use Phoenix.Component

  # ============================================================================
  # Formatting Helpers
  # ============================================================================

  @doc """
  Format number with thousand separators.
  """
  def format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  def format_number(number), do: to_string(number)

  @doc """
  Format duration in seconds to human readable format.
  """
  def format_duration(seconds) when is_float(seconds) do
    format_duration(round(seconds))
  end

  def format_duration(seconds) when is_integer(seconds) do
    cond do
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
      true -> "#{div(seconds, 3600)}h #{div(rem(seconds, 3600), 60)}m #{rem(seconds, 60)}s"
    end
  end

  def format_duration(_), do: "—"

  # ============================================================================
  # Prize Tier Helpers
  # ============================================================================

  @prize_descriptions %{
    1 => "(5+2)",
    2 => "(5+1)",
    3 => "(5+0)",
    4 => "(4+2)",
    5 => "(4+1)",
    6 => "(3+2)",
    7 => "(4+0)",
    8 => "(2+2)",
    9 => "(3+1)",
    10 => "(3+0)",
    11 => "(1+2)",
    12 => "(2+1)"
  }

  @doc """
  Get description for prize tier (e.g., "5+2" for tier 1).
  """
  def format_prize_description(tier) when is_integer(tier) do
    Map.get(@prize_descriptions, tier, "nieznany")
  end

  def format_prize_description(_), do: "nieznany"

  @doc """
  Get description for a prize tier of a specific game
  (e.g., "(5+2)" for Eurojackpot tier 1, "(6)" for Lotto tier 1).
  """
  def format_prize_description(tier, game) when is_integer(tier) do
    matches =
      Enum.find_value(game.prize_tiers, fn {matches, t} -> if t == tier, do: matches end)

    case matches do
      {main, _euro} when game.bonus.count == 0 -> "(#{main})"
      {main, euro} -> "(#{main}+#{euro})"
      nil -> "nieznany"
    end
  end

  def format_prize_description(_, _game), do: "nieznany"

  @doc """
  Sorted list of prize tier numbers for a game (Eurojackpot: 1..12, Lotto: 1..4).
  """
  def tier_numbers(game) do
    game.prize_tiers |> Map.values() |> Enum.sort()
  end
end
