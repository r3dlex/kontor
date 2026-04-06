defmodule Kontor.Contacts.ContactEmbedding do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contact_embeddings" do
    field :tenant_id, :string
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :contact, Kontor.Contacts.Contact

    timestamps(type: :utc_datetime)
  end

  def changeset(ce, attrs) do
    ce
    |> cast(attrs, [:tenant_id, :contact_id, :embedding])
    |> validate_required([:tenant_id, :contact_id, :embedding])
    |> unique_constraint(:contact_id)
  end
end
