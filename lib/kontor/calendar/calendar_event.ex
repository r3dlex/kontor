defmodule Kontor.Calendar.CalendarEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "calendar_events" do
    field :tenant_id, :string
    field :provider, Ecto.Enum, values: [:google, :microsoft]
    field :external_id, :string
    field :title, :string
    field :attendees, {:array, :string}, default: []
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :location, :string
    field :briefing_markdown, :string
    field :briefing_generated_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:tenant_id, :provider, :external_id, :title, :attendees,
                    :start_time, :end_time, :location, :briefing_markdown, :briefing_generated_at])
    |> validate_required([:tenant_id, :provider, :external_id, :title, :start_time, :end_time])
    |> unique_constraint([:tenant_id, :provider, :external_id])
  end
end
