defmodule Kontor.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :email_address, :string, null: false
      add :display_name, :string
      add :organization, :string
      add :role, :string
      add :profile_markdown, :text
      add :importance_weight, :float, default: 0.0
      add :first_seen, :utc_datetime
      add :last_seen, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:contacts, [:tenant_id, :email_address])
    create index(:contacts, [:tenant_id, :importance_weight])

    create table(:contact_mailbox_contexts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all), null: false
      add :mailbox_id, references(:mailboxes, type: :binary_id, on_delete: :delete_all), null: false
      add :context_role, :string
      add :interaction_frequency, :integer, default: 0
      add :avg_response_time_hours, :float
      add :topics, :map, default: %{}
      add :last_interaction, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:contact_mailbox_contexts, [:contact_id, :mailbox_id])

    create table(:contact_relationships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :contact_a_id, :binary_id, null: false
      add :contact_b_id, :binary_id, null: false
      add :relationship_type, :string, null: false
      add :weight, :float, default: 0.0
      add :evidence_summary, :text
      add :created_by, :string, default: "llm"
      add :last_updated, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:contact_relationships, [:tenant_id, :contact_a_id, :contact_b_id, :relationship_type])
    create index(:contact_relationships, [:tenant_id])

    execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"

    create table(:contact_embeddings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all), null: false
      add :embedding, :vector, size: 384

      timestamps(type: :utc_datetime)
    end

    create unique_index(:contact_embeddings, [:contact_id])
    execute "CREATE INDEX IF NOT EXISTS contact_embeddings_embedding_idx ON contact_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)", ""

    create table(:org_charts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :name, :string, null: false
      add :structure_json, :map, default: %{}
      add :source, :string, default: "manual"

      timestamps(type: :utc_datetime)
    end

    create index(:org_charts, [:tenant_id])
  end
end
