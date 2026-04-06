defmodule Kontor.Contacts.OrgChart do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "org_charts" do
    field :tenant_id, :string
    field :name, :string
    field :structure_json, :map, default: %{}
    field :source, Ecto.Enum, values: [:import, :manual, :inferred], default: :manual

    timestamps(type: :utc_datetime)
  end

  def changeset(chart, attrs) do
    chart
    |> cast(attrs, [:tenant_id, :name, :structure_json, :source])
    |> validate_required([:tenant_id, :name])
  end
end
