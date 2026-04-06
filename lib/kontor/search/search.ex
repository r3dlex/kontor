defmodule Kontor.Search do
  @moduledoc "Semantic search across threads and contacts using pgvector."

  require Logger

  @default_limit 10
  @default_threshold 0.5

  @doc """
  Performs semantic search over thread embeddings for the given tenant.

  Returns a list of maps with :thread_id, :thread_subject, and :similarity_score.
  """
  def semantic_search(query_text, tenant_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    threshold = Keyword.get(opts, :threshold, @default_threshold)

    with {:ok, embedding} <- Kontor.AI.Embeddings.embed(query_text) do
      run_search(embedding, tenant_id, limit, threshold)
    end
  end

  defp run_search(embedding, tenant_id, limit, threshold) do
    vector_literal = "[#{Enum.join(embedding, ",")}]"

    sql = """
    SELECT
      te.thread_id,
      t.thread_id AS subject,
      1 - (te.embedding <=> $1::vector) AS similarity_score
    FROM thread_embeddings te
    LEFT JOIN threads t ON t.id = te.thread_id
    WHERE te.tenant_id = $2
      AND 1 - (te.embedding <=> $1::vector) > $3
    ORDER BY te.embedding <=> $1::vector
    LIMIT $4
    """

    case Ecto.Adapters.SQL.query(Kontor.Repo, sql, [vector_literal, tenant_id, threshold, limit]) do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn [thread_id, subject, score] ->
            %{thread_id: thread_id, thread_subject: subject, similarity_score: score}
          end)

        {:ok, results}

      {:error, reason} ->
        Logger.error("Search query failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
