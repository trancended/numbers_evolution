defmodule NumbersEvolution.Client.OpenRouterClient do
  @moduledoc """
  Low-level HTTP client for OpenRouter API communication.

  This module handles only the HTTP communication with OpenRouter API.
  It provides methods for making requests and handling responses, but does not
  contain business logic like rate limiting, validation, or strategy processing.

  ## Configuration

  Configure the OpenRouter API in your config files:

      config :numbers_evolution, :openrouter,
        api_key: System.get_env("OPENROUTER_API_KEY"),
        base_url: "https://openrouter.ai/api/v1",
        default_model: "openai/gpt-4o-mini",
        timeout: 30_000,
        rate_limit_per_hour: 100
  """

  @doc """
  Makes a chat completion request to OpenRouter API.

  ## Parameters
  - `payload`: Request payload map
  - `opts`: Options (api_key, model, timeout overrides)

  ## Returns
  - `{:ok, response}` - Successful API response
  - `{:error, reason}` - API or network error
  """
  @spec chat_completion(map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def chat_completion(payload, opts \\ []) do
    config = config()

    # Override config with opts
    api_key = Keyword.get(opts, :api_key, config[:api_key])
    base_url = Keyword.get(opts, :base_url, config[:base_url])
    timeout = Keyword.get(opts, :timeout, config[:timeout])

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    Req.post("#{base_url}/chat/completions",
      headers: headers,
      json: payload,
      receive_timeout: timeout
    )
    |> handle_api_response()
  rescue
    _ -> {:error, :api_key_missing}
  end

  @doc """
  Lists available models from OpenRouter API.

  ## Parameters
  - `opts`: Options (api_key, base_url, timeout overrides)

  ## Returns
  - `{:ok, [String.t()]}` - List of available model names
  - `{:error, atom()}` - API error
  """
  @spec list_models(keyword()) :: {:ok, [String.t()]} | {:error, atom()}
  def list_models(opts \\ []) do
    config = config()
    api_key = Keyword.get(opts, :api_key, config[:api_key])
    base_url = Keyword.get(opts, :base_url, config[:base_url])
    timeout = Keyword.get(opts, :timeout, config[:timeout])

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    case Req.get("#{base_url}/models", headers: headers, receive_timeout: timeout) do
      {:ok, %{status: 200, body: %{"data" => models}}} ->
        model_names = Enum.map(models, & &1["id"])
        {:ok, model_names}

      {:ok, %{status: status}} when status >= 400 ->
        {:error, :api_error}

      {:error, _} ->
        {:error, :network_error}
    end
  rescue
    _ -> {:error, :unexpected_error}
  end

  @doc """
  Validates if API configuration is present.

  ## Returns
  - `:ok` - Configuration is valid
  - `{:error, :api_key_missing}` - API key not configured
  """
  @spec validate_config() :: :ok | {:error, :api_key_missing}
  def validate_config do
    if config()[:api_key] do
      :ok
    else
      {:error, :api_key_missing}
    end
  end

  # Private methods

  defp config do
    Application.get_env(:numbers_evolution, :openrouter, %{
      api_key: nil,
      base_url: "https://openrouter.ai/api/v1",
      default_model: "openai/gpt-4o-mini",
      timeout: 30_000,
      rate_limit_per_hour: 100
    })
  end

  defp handle_api_response({:ok, %{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_api_response({:ok, %{status: 429}}) do
    {:error, :rate_limit_exceeded}
  end

  defp handle_api_response({:ok, %{status: status}}) when status >= 400 and status < 500 do
    {:error, :client_error}
  end

  defp handle_api_response({:ok, %{status: status}}) when status >= 500 do
    {:error, :server_error}
  end

  defp handle_api_response({:error, %Req.TransportError{reason: :timeout}}) do
    {:error, :timeout}
  end

  defp handle_api_response({:error, _}) do
    {:error, :network_error}
  end
end
