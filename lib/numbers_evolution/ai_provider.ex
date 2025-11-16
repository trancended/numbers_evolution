defmodule NumbersEvolution.AIProvider do
  @moduledoc """
  Behaviour for AI strategy generation providers.

  Handles generating lottery strategies from text prompts.
  Default implementation uses pattern matching for common strategies.
  Can be replaced with actual AI API integration (Claude, GPT, etc.)
  """

  @type strategy_response :: %{
          strategy_name: String.t(),
          description: String.t(),
          reasoning: String.t(),
          rules: map()
        }

  @callback generate_strategy(prompt :: String.t()) ::
              {:ok, strategy_response()} | {:error, atom()}

  @doc """
  Generates a strategy based on a text prompt.

  Delegates to the configured provider (default: Mock implementation).

  ## Examples

      iex> AIProvider.generate_strategy("Pomin połowę liczb (wszystkie parzyste)")
      {:ok, %{
        strategy_name: "Tylko Nieparzyste",
        description: "Strategia pomijająca wszystkie parzyste liczby główne",
        rules: %{...}
      }}
  """
  @spec generate_strategy(String.t()) :: {:ok, strategy_response()} | {:error, atom()}
  def generate_strategy(prompt) when is_binary(prompt) do
    provider().generate_strategy(prompt)
  end

  defp provider do
    Application.get_env(:numbers_evolution, :ai_provider, NumbersEvolution.AIProvider.Mock)
  end
end
