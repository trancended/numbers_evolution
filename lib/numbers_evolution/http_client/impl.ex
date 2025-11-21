defmodule NumbersEvolution.HTTPClient.Impl do
  @moduledoc """
  Default HTTP client implementation using Req.
  """

  @behaviour NumbersEvolution.HTTPClient

  @impl true
  def post(url, opts) do
    Req.post(url, opts)
  end
end
