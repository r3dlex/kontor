defmodule Kontor.Repo.Migrations.CreateStyleProfiles do
  use Ecto.Migration

  def change do
    create table(:style_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :name, :string, null: false
      add :content, :text
      add :preserve_voice, :boolean, default: false
      add :auto_select_rules, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:style_profiles, [:tenant_id, :name])
  end
end
