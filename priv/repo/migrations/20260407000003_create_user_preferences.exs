defmodule Kontor.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :theme, :string, null: false, default: "system"
      add :polling_interval_seconds, :integer, null: false, default: 60
      add :read_only_mode, :boolean, null: false, default: false
      add :font_size, :string, null: false, default: "medium"
      add :extra, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_preferences, [:tenant_id])
  end
end
