defmodule Kontor.Automations.Webhook do
  @moduledoc "Ecto schema for webhook registrations used in n8n automation integration."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhooks" do
    field :tenant_id, :string
    field :name, :string
    field :url, :string
    field :event_types, {:array, :string}, default: []
    field :active, :boolean, default: true
    field :secret, :string
    field :last_triggered_at, :utc_datetime
    field :failure_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:tenant_id, :name, :url, :event_types, :active, :secret, :last_triggered_at, :failure_count])
    |> validate_required([:tenant_id, :name, :url])
    |> validate_format(:url, ~r/^https?:\/\//, message: "must be a valid HTTP or HTTPS URL")
  end
end
