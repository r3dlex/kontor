defmodule Kontor.AI.MinimaxClient do
  @moduledoc """
  MiniMax LLM API client with Strategy C aggressive caching.
  Identical prompt hashes return cached responses without an API call.
  TTL defaults to 1 hour.
  """

  require Logger

  @cache_table :minimax_response_cache

  def child_spec(_opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_cache, []}, type: :worker}
  end

  def start_cache do
    if :ets.whereis(@cache_table) == :undefined do
      :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
    end

    {:ok, self()}
  end

  def complete(prompt, _tenant_id, opts \\ []) do
    key = opts[:cache_key] || hash_prompt(prompt)

    case get_cached(key) do
      {:ok, cached} ->
        Logger.debug("MinimaxClient: cache hit")
        {:ok, cached}

      :miss ->
        case call_api(prompt) do
          {:ok, result} = ok ->
            put_cache(key, result)
            ok

          error ->
            error
        end
    end
  end

  defp call_api(prompt) do
    cfg = Application.get_env(:kontor, :minimax, [])
    api_key = cfg[:api_key]
    base_url = cfg[:base_url] || "https://api.minimax.chat/v1"
    model = cfg[:model] || "abab6.5s-chat"
    max_tokens = cfg[:max_tokens] || 4096

    if is_nil(api_key) do
      Logger.warning("MinimaxClient: MINIMAX_API_KEY not set, returning mock response")
      {:ok, %{"_mock" => true, "content" => "LLM response placeholder"}}
    else
      do_call_api(base_url, api_key, model, max_tokens, prompt)
    end
  end

  defp do_call_api(base_url, api_key, model, max_tokens, prompt) do

    body = %{
      model: model,
      messages: [%{role: "user", content: prompt}],
      max_tokens: max_tokens,
      response_format: %{type: "json_object"}
    }

    case Req.post("#{base_url}/text/chatcompletion_v2",
           json: body,
           headers: [{"Authorization", "Bearer #{api_key}"}],
           receive_timeout: 30_000) do
      {:ok, %{status: 200, body: resp}} ->
        content = get_in(resp, ["choices", Access.at(0), "message", "content"])

        case Jason.decode(content || "{}") do
          {:ok, parsed} -> {:ok, parsed}
          _ -> {:ok, %{"raw" => content}}
        end

      {:ok, %{status: status}} ->
        {:error, {:api_error, status}}

      {:error, reason} ->
        Logger.error("MinimaxClient: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp hash_prompt(prompt) do
    :crypto.hash(:sha256, prompt) |> Base.encode16(case: :lower)
  end

  defp get_cached(key) do
    ttl = Application.get_env(:kontor, :minimax, [])[:cache_ttl_seconds] || 3600

    case :ets.lookup(@cache_table, key) do
      [{^key, value, inserted_at}] ->
        if System.system_time(:second) - inserted_at < ttl, do: {:ok, value}, else: :miss
      [] ->
        :miss
    end
  end

  defp put_cache(key, value) do
    :ets.insert(@cache_table, {key, value, System.system_time(:second)})
  end
end
