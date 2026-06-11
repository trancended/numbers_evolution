defmodule NumbersEvolution.HTTPClient do
  @moduledoc """
  Behaviour for HTTP client operations.

  This behaviour defines the interface for HTTP operations that can be mocked in tests.
  """

  @callback post(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
  @callback get(String.t(), keyword()) :: {:ok, map()} | {:error, any()}
end
