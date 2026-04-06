defmodule Kontor.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :email, :string, null: false
      add :name, :string
      add :preferences_md_path, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:tenant_id, :email])
    create index(:users, [:tenant_id])
  end
end
