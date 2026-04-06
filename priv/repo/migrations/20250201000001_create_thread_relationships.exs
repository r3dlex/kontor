defmodule Kontor.Repo.Migrations.CreateThreadRelationships do
  use Ecto.Migration

  def change do
    create table(:thread_relationships) do
      add :tenant_id, :string, null: false
      add :thread_a_id, references(:threads, on_delete: :delete_all, type: :binary_id), null: false
      add :thread_b_id, references(:threads, on_delete: :delete_all, type: :binary_id), null: false
      add :similarity_score, :float, null: false
      add :relationship_type, :string, default: "semantic"
      timestamps()
    end

    create unique_index(:thread_relationships, [:thread_a_id, :thread_b_id])
    create index(:thread_relationships, [:tenant_id])
    create index(:thread_relationships, [:thread_a_id])
    create index(:thread_relationships, [:thread_b_id])
  end
end
