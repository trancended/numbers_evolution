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

  require Logger

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

    # Log the request
    Logger.info("[OpenRouter] Sending chat completion request to #{base_url}/chat/completions",
      payload_size: byte_size(Jason.encode!(payload)),
      model: payload["model"],
      messages_count: length(payload["messages"] || []),
      timeout: timeout
    )

    start_time = System.monotonic_time(:millisecond)

    http_client = Application.get_env(:numbers_evolution, :http_client, NumbersEvolution.HTTPClient.Impl)

    result =
      http_client.post("#{base_url}/chat/completions",
        headers: headers,
        json: payload,
        receive_timeout: timeout
      )

    duration = System.monotonic_time(:millisecond) - start_time

    # Log the response
    case result do
      {:ok, %{status: status, body: body}} ->
        Logger.info("[OpenRouter] Received response",
          status: status,
          duration_ms: duration,
          response_size: byte_size(Jason.encode!(body))
        )

        if status >= 400 do
          Logger.warning("[OpenRouter] API error response",
            status: status,
            error_body: inspect(body, limit: 500)
          )
        end

      {:error, error} ->
        Logger.error("[OpenRouter] Request failed",
          duration_ms: duration,
          error: inspect(error, limit: 500)
        )
    end

    result
    |> handle_api_response()
  rescue
    exception ->
      Logger.error("[OpenRouter] Unexpected error in chat_completion",
        error: inspect(exception, limit: 500)
      )

      {:error, :api_key_missing}
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

    # Log the request
    Logger.info("[OpenRouter] Requesting models list from #{base_url}/models",
      timeout: timeout
    )

    start_time = System.monotonic_time(:millisecond)

    result = Req.get("#{base_url}/models", headers: headers, receive_timeout: timeout)

    duration = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{status: 200, body: %{"data" => models}}} ->
        model_names = Enum.map(models, & &1["id"])

        Logger.info("[OpenRouter] Successfully retrieved models list",
          duration_ms: duration,
          models_count: length(model_names)
        )

        {:ok, model_names}

      {:ok, %{status: status, body: body}} when status >= 400 ->
        Logger.warning("[OpenRouter] Models API error",
          status: status,
          duration_ms: duration,
          error_body: inspect(body, limit: 500)
        )

        {:error, :api_error}

      {:error, error} ->
        Logger.error("[OpenRouter] Models request failed",
          duration_ms: duration,
          error: inspect(error, limit: 500)
        )

        {:error, :network_error}
    end
  rescue
    exception ->
      Logger.error("[OpenRouter] Unexpected error in list_models",
        error: inspect(exception, limit: 500)
      )

      {:error, :unexpected_error}
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
