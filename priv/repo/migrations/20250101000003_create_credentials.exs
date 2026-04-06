defmodule Kontor.Repo.Migrations.CreateCredentials do
  use Ecto.Migration

  def change do
    create table(:credentials, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :mailbox_id, references(:mailboxes, type: :binary_id, on_delete: :delete_all)
      add :provider, :string, null: false
      add :access_token_encrypted, :binary
      add :refresh_token_encrypted, :binary
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:credentials, [:tenant_id])
    create index(:credentials, [:user_id])
    create index(:credentials, [:mailbox_id])
  end
end
