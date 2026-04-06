defmodule Kontor.Repo.Migrations.CreateThreadEmbeddings do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"

    create table(:thread_embeddings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :thread_id, :binary_id, null: false
      add :embedding, :vector, size: 384

      timestamps(type: :utc_datetime)
    end

    create index(:thread_embeddings, [:tenant_id])
    create index(:thread_embeddings, [:thread_id])
    execute "CREATE INDEX thread_embeddings_embedding_idx ON thread_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)",
            "DROP INDEX IF EXISTS thread_embeddings_embedding_idx"
  end
end
