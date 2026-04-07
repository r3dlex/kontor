defmodule Kontor.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :type, :string, null: false, default: "other"
      add :title, :string, null: false
      add :content, :text
      add :source, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:documents, [:tenant_id])
    create index(:documents, [:tenant_id, :type])
  end
end
