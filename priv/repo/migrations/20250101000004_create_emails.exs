defmodule Kontor.Repo.Migrations.CreateEmails do
  use Ecto.Migration

  def change do
    create table(:emails, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :mailbox_id, references(:mailboxes, type: :binary_id, on_delete: :delete_all), null: false
      add :message_id, :string, null: false
      add :thread_id, :string
      add :subject, :string
      add :sender, :string
      add :recipients, {:array, :string}, default: []
      add :body, :text
      add :raw_headers, :map, default: %{}
      add :received_at, :utc_datetime
      add :processed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:emails, [:tenant_id, :message_id])
    create index(:emails, [:tenant_id])
    create index(:emails, [:mailbox_id])
    create index(:emails, [:thread_id])
    create index(:emails, [:received_at])
  end
end
