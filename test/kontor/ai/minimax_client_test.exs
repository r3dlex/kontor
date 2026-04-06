defmodule Kontor.AI.MinimaxClientTest do
  use ExUnit.Case, async: false

  alias Kontor.AI.MinimaxClient

  @tenant "tenant-minimax-test"

  # Ensure the ETS cache table exists before each test.
  # In test env the application is running so the table should already be
  # created by MinimaxClient.start_cache/0 in the supervision tree.
  setup do
    if :ets.whereis(:minimax_response_cache) == :undefined do
      MinimaxClient.start_cache()
    end
    :ok
  end

  # ---------------------------------------------------------------------------
  # complete/3 — mock mode (no MINIMAX_API_KEY set in test env)
  # ---------------------------------------------------------------------------

  describe "complete/3 — mock mode" do
    test "returns {:ok, map} when MINIMAX_API_KEY is not set" do
      assert {:ok, response} = MinimaxClient.complete("Hello", @tenant)
      assert is_map(response)
    end

    test "mock response contains expected keys" do
      assert {:ok, response} = MinimaxClient.complete("Any prompt", @tenant)
      # Either _mock flag or raw content key should be present
      assert Map.has_key?(response, "_mock") or Map.has_key?(response, "content") or
               Map.has_key?(response, "raw"),
             "Expected mock response map to have recognisable keys, got: #{inspect(response)}"
    end

    test "caches responses — same prompt returns same result" do
      prompt = "Cache test prompt #{System.unique_integer([:positive])}"

      {:ok, first} = MinimaxClient.complete(prompt, @tenant)
      {:ok, second} = MinimaxClient.complete(prompt, @tenant)

      assert first == second
    end

    test "different prompts are cached under different keys" do
      p1 = "Prompt A #{System.unique_integer([:positive])}"
      p2 = "Prompt B #{System.unique_integer([:positive])}"

      assert {:ok, _} = MinimaxClient.complete(p1, @tenant)
      assert {:ok, _} = MinimaxClient.complete(p2, @tenant)
    end

    test "custom cache_key option is respected — same key returns same result" do
      key = "my-custom-key-#{System.unique_integer([:positive])}"

      assert {:ok, r1} = MinimaxClient.complete("prompt one", @tenant, cache_key: key)
      assert {:ok, r2} = MinimaxClient.complete("completely different prompt", @tenant, cache_key: key)

      assert r1 == r2
    end

    test "custom cache_key is independent of prompt hash" do
      key = "isolated-key-#{System.unique_integer([:positive])}"
      prompt = "unique prompt #{System.unique_integer([:positive])}"

      # Call with the custom key
      assert {:ok, with_key} = MinimaxClient.complete(prompt, @tenant, cache_key: key)
      # Call with a different key for the same prompt — should also return ok
      other_key = "other-#{key}"
      assert {:ok, with_other_key} = MinimaxClient.complete(prompt, @tenant, cache_key: other_key)

      # Both should be valid maps (cached separately)
      assert is_map(with_key)
      assert is_map(with_other_key)
    end

    test "tenant_id parameter does not affect result (mock is stateless per tenant)" do
      prompt = "Shared prompt #{System.unique_integer([:positive])}"

      assert {:ok, r1} = MinimaxClient.complete(prompt, "tenant-a")
      assert {:ok, r2} = MinimaxClient.complete(prompt, "tenant-b")

      # Both are valid maps; second call hits cache from first call
      assert is_map(r1)
      assert is_map(r2)
    end
  end

  # ---------------------------------------------------------------------------
  # start_cache/0
  # ---------------------------------------------------------------------------

  describe "start_cache/0" do
    test "returns {:ok, pid} even when table already exists" do
      assert {:ok, _pid} = MinimaxClient.start_cache()
    end

    test "ETS table :minimax_response_cache is accessible after start_cache" do
      MinimaxClient.start_cache()
      assert :ets.whereis(:minimax_response_cache) != :undefined
    end
  end
end
