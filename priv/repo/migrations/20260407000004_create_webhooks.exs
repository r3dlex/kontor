defmodule Kontor.Repo.Migrations.CreateWebhooks do
  use Ecto.Migration

  def change do
    create table(:webhooks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :name, :string, null: false
      add :url, :string, null: false
      add :event_types, {:array, :string}, null: false, default: []
      add :active, :boolean, null: false, default: true
      add :secret, :string
      add :last_triggered_at, :utc_datetime
      add :failure_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:webhooks, [:tenant_id, :active])
  end
end
