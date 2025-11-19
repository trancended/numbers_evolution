defmodule NumbersEvolution.Client.OpenRouterClientTest do
  use NumbersEvolution.DataCase, async: true

  alias NumbersEvolution.Client.OpenRouterClient

  describe "chat_completion/2" do
    test "requires valid configuration" do
      payload = %{model: "test", messages: []}

      # Ensure we have valid config for this test
      original_config = Application.get_env(:numbers_evolution, :openrouter)
      test_config = %{api_key: "test-key", base_url: "https://test.com", timeout: 1000}
      Application.put_env(:numbers_evolution, :openrouter, test_config)

      # This will fail due to invalid URL, but tests that method accepts valid config
      result = OpenRouterClient.chat_completion(payload)

      # Restore config
      if original_config do
        Application.put_env(:numbers_evolution, :openrouter, original_config)
      else
        Application.delete_env(:numbers_evolution, :openrouter)
      end

      # Should return some kind of error (network, not config validation)
      assert match?({:error, _}, result)
    end
  end

  describe "list_models/1" do
    test "requires valid configuration" do
      # Ensure we have valid config for this test
      original_config = Application.get_env(:numbers_evolution, :openrouter)
      test_config = %{api_key: "test-key", base_url: "https://test.com", timeout: 1000}
      Application.put_env(:numbers_evolution, :openrouter, test_config)

      result = OpenRouterClient.list_models()

      # Restore config
      if original_config do
        Application.put_env(:numbers_evolution, :openrouter, original_config)
      else
        Application.delete_env(:numbers_evolution, :openrouter)
      end

      # Should return some kind of error (network, not config validation)
      assert match?({:error, _}, result)
    end
  end

  describe "validate_config/0" do
    test "returns :ok when API key is configured" do
      # Ensure we have a config with API key
      original_config = Application.get_env(:numbers_evolution, :openrouter)
      test_config = %{api_key: "test-key", base_url: "https://test.com"}
      Application.put_env(:numbers_evolution, :openrouter, test_config)

      result = OpenRouterClient.validate_config()

      # Restore config
      if original_config do
        Application.put_env(:numbers_evolution, :openrouter, original_config)
      else
        Application.delete_env(:numbers_evolution, :openrouter)
      end

      assert result == :ok
    end

    test "returns error when API key is missing" do
      # Temporarily clear API key
      original_config = Application.get_env(:numbers_evolution, :openrouter)
      Application.put_env(:numbers_evolution, :openrouter, Map.put(original_config || %{}, :api_key, nil))

      result = OpenRouterClient.validate_config()

      # Restore config
      if original_config do
        Application.put_env(:numbers_evolution, :openrouter, original_config)
      else
        Application.delete_env(:numbers_evolution, :openrouter)
      end

      assert result == {:error, :api_key_missing}
    end
  end
end
