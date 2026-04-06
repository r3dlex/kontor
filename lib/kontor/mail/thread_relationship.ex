defmodule Kontor.Mail.ThreadRelationship do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_relationships" do
    field :tenant_id, :string
    field :similarity_score, :float
    field :relationship_type, :string, default: "semantic"
    belongs_to :thread_a, Kontor.Mail.Thread
    belongs_to :thread_b, Kontor.Mail.Thread
    timestamps()
  end

  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [:tenant_id, :thread_a_id, :thread_b_id, :similarity_score, :relationship_type])
    |> validate_required([:tenant_id, :thread_a_id, :thread_b_id, :similarity_score])
    |> unique_constraint([:thread_a_id, :thread_b_id])
  end
end
