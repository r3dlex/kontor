defmodule Kontor.Repo.Migrations.CreateChat do
  use Ecto.Migration

  def change do
    create table(:chat_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :view_origin, :string
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:chat_sessions, [:tenant_id, :user_id])

    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :session_id, references(:chat_sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :role, :string, null: false
      add :content, :text, null: false
      add :view_context, :map, default: %{}
      add :thread_id, :binary_id
      add :task_id, :binary_id
      add :skill_invoked, :string

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:session_id])
    create index(:chat_messages, [:tenant_id])
  end
end
