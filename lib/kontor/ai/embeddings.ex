defmodule Kontor.AI.Embeddings do
  @moduledoc """
  Bumblebee/Nx embedding server using all-MiniLM-L6-v2 (~80MB, 384 dimensions).
  Loaded asynchronously on startup to avoid blocking the supervision tree.
  Used for pgvector semantic similarity (thread relationships, contact embeddings).
  Falls back gracefully when Bumblebee/EXLA are not available (dev/test).
  """

  use GenServer
  require Logger

  @nx_available Code.ensure_loaded?(Nx)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def embed(text) when is_binary(text) do
    GenServer.call(__MODULE__, {:embed, text}, 30_000)
  end

  def embed_batch(texts) when is_list(texts) do
    GenServer.call(__MODULE__, {:embed_batch, texts}, 60_000)
  end

  @impl true
  def init(_opts) do
    send(self(), :load_model)
    {:ok, %{serving: nil, loading: true}}
  end

  @impl true
  def handle_info(:load_model, state) do
    case load_model() do
      {:ok, serving} ->
        Logger.info("Embeddings: all-MiniLM-L6-v2 ready (384 dims)")
        {:noreply, %{state | serving: serving, loading: false}}

      {:error, reason} ->
        Logger.error("Embeddings: model load failed: #{inspect(reason)}")
        {:noreply, %{state | loading: false}}
    end
  end

  @impl true
  def handle_call(_, _from, %{loading: true} = state) do
    {:reply, {:error, :model_loading}, state}
  end

  def handle_call({:embed, text}, _from, %{serving: serving} = state) when not is_nil(serving) do
    result = run_serving(serving, text)
    {:reply, result, state}
  end

  def handle_call({:embed_batch, texts}, _from, %{serving: serving} = state) when not is_nil(serving) do
    embeddings = Enum.map(texts, fn t ->
      case run_serving(serving, t) do
        {:ok, vec} -> vec
        _ -> []
      end
    end)
    {:reply, {:ok, embeddings}, state}
  end

  def handle_call(_, _from, state) do
    {:reply, {:error, :model_not_loaded}, state}
  end

  if @nx_available do
    defp run_serving(serving, text) do
      result = Nx.Serving.run(serving, text)
      {:ok, Nx.to_flat_list(result.embedding)}
    end
  else
    defp run_serving(_serving, _text), do: {:error, :nx_not_available}
  end

  defp load_model do
    if @nx_available do
      do_load_model()
    else
      Logger.warning("Embeddings: Nx/Bumblebee not available in this environment")
      {:error, :nx_not_available}
    end
  end

  defp do_load_model do
    try do
      {:ok, model_info} = Bumblebee.load_model({:hf, "sentence-transformers/all-MiniLM-L6-v2"})
      {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "sentence-transformers/all-MiniLM-L6-v2"})

      serving = Bumblebee.Text.text_embedding(model_info, tokenizer,
        compile: [batch_size: 32, sequence_length: 512],
        defn_options: [compiler: EXLA]
      )

      {:ok, serving}
    rescue
      e -> {:error, e}
    end
  end
end
