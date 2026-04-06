defmodule Kontor.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :namespace, :string, null: false, default: "shared"
      add :name, :string, null: false
      add :version, :integer, null: false, default: 1
      add :content, :text
      add :author, :string, null: false, default: "system"
      add :locked, :boolean, default: false
      add :active, :boolean, default: true
      add :webhook_url, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:skills, [:tenant_id, :namespace, :name])
    create index(:skills, [:tenant_id, :active])

    create table(:skill_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :skill_id, references(:skills, type: :binary_id, on_delete: :delete_all), null: false
      add :version, :integer, null: false
      add :content, :text
      add :author, :string
      add :diff, :text

      timestamps(type: :utc_datetime)
    end

    create index(:skill_versions, [:skill_id])
  end
end
