defmodule Kontor.Repo.Migrations.CreateMcpCredentials do
  use Ecto.Migration

  def change do
    create table(:mcp_credentials, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :server_name, :string, null: false
      add :token_hash, :string
      add :permissions, {:array, :string}, default: []
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:mcp_credentials, [:tenant_id])
    create unique_index(:mcp_credentials, [:tenant_id, :server_name])
  end
end
