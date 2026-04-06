defmodule Kontor.Contacts.ContactRelationship do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contact_relationships" do
    field :tenant_id, :string
    field :contact_a_id, :binary_id
    field :contact_b_id, :binary_id
    field :relationship_type, :string
    field :weight, :float, default: 0.0
    field :evidence_summary, :string
    field :created_by, Ecto.Enum, values: [:llm, :user], default: :llm
    field :last_updated, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(rel, attrs) do
    rel
    |> cast(attrs, [:tenant_id, :contact_a_id, :contact_b_id, :relationship_type,
                    :weight, :evidence_summary, :created_by, :last_updated])
    |> validate_required([:tenant_id, :contact_a_id, :contact_b_id, :relationship_type])
    |> unique_constraint([:tenant_id, :contact_a_id, :contact_b_id, :relationship_type])
  end
end
