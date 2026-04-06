defmodule Kontor.Mail.ThreadRelationshipWorker do
  @moduledoc "Discovers semantically related threads using pgvector cosine similarity."
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger
  import Ecto.Query

  @similarity_threshold 0.75

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id}}) do
    discover_relationships(tenant_id)
  end

  def perform(%Oban.Job{}) do
    tenant_ids =
      Kontor.Repo.all(
        from te in Kontor.Mail.ThreadEmbedding,
        select: te.tenant_id,
        distinct: true
      )

    Enum.each(tenant_ids, &discover_relationships/1)
    :ok
  end

  defp discover_relationships(tenant_id) do
    Logger.info("ThreadRelationshipWorker: discovering relationships for tenant #{tenant_id}")

    sql = """
    INSERT INTO thread_relationships (id, tenant_id, thread_a_id, thread_b_id, similarity_score, relationship_type, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      $1,
      a.thread_id,
      b.thread_id,
      1 - (a.embedding <=> b.embedding),
      'semantic',
      NOW(),
      NOW()
    FROM thread_embeddings a
    JOIN thread_embeddings b ON a.thread_id < b.thread_id AND a.tenant_id = b.tenant_id
    WHERE a.tenant_id = $1
      AND 1 - (a.embedding <=> b.embedding) > $2
    ON CONFLICT (thread_a_id, thread_b_id)
    DO UPDATE SET
      similarity_score = EXCLUDED.similarity_score,
      updated_at = NOW()
    """

    case Ecto.Adapters.SQL.query(Kontor.Repo, sql, [tenant_id, @similarity_threshold]) do
      {:ok, result} ->
        Logger.info("ThreadRelationshipWorker: upserted #{result.num_rows} relationships for tenant #{tenant_id}")
        :ok

      {:error, reason} ->
        Logger.error("ThreadRelationshipWorker: failed for tenant #{tenant_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def schedule do
    %{}
    |> new(schedule_in: 30 * 60)
    |> Oban.insert()
  end
end
