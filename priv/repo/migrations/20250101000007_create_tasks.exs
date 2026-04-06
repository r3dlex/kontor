defmodule Kontor.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :thread_id, :binary_id
      add :email_id, :binary_id
      add :task_type, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :importance, :float, default: 0.0
      add :status, :string, null: false, default: "created"
      add :confidence, :float, default: 0.0
      add :draft_content, :text
      add :style_profile_used, :string
      add :asana_sync_id, :string
      add :scheduled_action_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:tenant_id])
    create index(:tasks, [:tenant_id, :status])
    create index(:tasks, [:tenant_id, :importance])
    create index(:tasks, [:asana_sync_id])
  end
end
