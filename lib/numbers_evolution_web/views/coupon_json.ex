defmodule NumbersEvolutionWeb.CouponJSON do
  @moduledoc """
  JSON rendering for generated coupons.
  """

  @doc """
  Renders generated coupons.
  """
  def generate(%{coupons: coupons, game_type: game_type, strategy: strategy}) do
    %{
      data: %{
        game_type: game_type,
        strategy: %{
          id: strategy.id,
          name: strategy.name
        },
        coupons: for(coupon <- coupons, do: render_coupon(coupon)),
        generated_at: DateTime.utc_now()
      }
    }
  end

  defp render_coupon(numbers) do
    %{
      main_numbers: numbers.main,
      euro_numbers: numbers.euro
    }
  end
end
