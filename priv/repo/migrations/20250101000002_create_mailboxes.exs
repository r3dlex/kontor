defmodule Kontor.Repo.Migrations.CreateMailboxes do
  use Ecto.Migration

  def change do
    create table(:mailboxes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :email_address, :string, null: false
      add :himalaya_config, :map, default: %{}
      add :polling_interval_seconds, :integer, default: 60
      add :task_age_cutoff_months, :integer, default: 3
      add :read_only, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mailboxes, [:tenant_id, :email_address])
    create index(:mailboxes, [:tenant_id])
    create index(:mailboxes, [:user_id])
  end
end
