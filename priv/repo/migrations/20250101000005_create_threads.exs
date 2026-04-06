defmodule Kontor.Repo.Migrations.CreateThreads do
  use Ecto.Migration

  def change do
    create table(:threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :thread_id, :string, null: false
      add :markdown_content, :text
      add :last_updated, :utc_datetime
      add :score_urgency, :float, default: 0.0
      add :score_action, :float, default: 0.0
      add :score_authority, :float, default: 0.0
      add :score_momentum, :float, default: 0.0
      add :composite_score, :float, default: 0.0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:threads, [:tenant_id, :thread_id])
    create index(:threads, [:tenant_id])
    create index(:threads, [:composite_score])
  end
end
