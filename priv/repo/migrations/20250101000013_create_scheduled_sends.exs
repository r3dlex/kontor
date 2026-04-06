defmodule Kontor.Repo.Migrations.CreateScheduledSends do
  use Ecto.Migration

  def change do
    create table(:scheduled_sends, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :mailbox_id, references(:mailboxes, type: :binary_id, on_delete: :restrict), null: false
      add :draft_content, :text, null: false
      add :recipients, {:array, :string}, null: false
      add :subject, :string
      add :scheduled_at, :utc_datetime
      add :status, :string, null: false, default: "pending"
      add :sent_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:scheduled_sends, [:tenant_id, :status])
    create index(:scheduled_sends, [:scheduled_at])
  end
end
