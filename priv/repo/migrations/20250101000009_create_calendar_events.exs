defmodule Kontor.Repo.Migrations.CreateCalendarEvents do
  use Ecto.Migration

  def change do
    create table(:calendar_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :provider, :string, null: false
      add :external_id, :string, null: false
      add :title, :string, null: false
      add :attendees, {:array, :string}, default: []
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime, null: false
      add :location, :string
      add :briefing_markdown, :text
      add :briefing_generated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:calendar_events, [:tenant_id, :provider, :external_id])
    create index(:calendar_events, [:tenant_id, :start_time])
  end
end
