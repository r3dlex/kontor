defmodule Kontor.Contacts.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contacts" do
    field :tenant_id, :string
    field :email_address, :string
    field :display_name, :string
    field :organization, :string
    field :role, :string
    field :profile_markdown, :string
    field :importance_weight, :float, default: 0.0
    field :first_seen, :utc_datetime
    field :last_seen, :utc_datetime

    has_many :mailbox_contexts, Kontor.Contacts.ContactMailboxContext
    has_many :embeddings, Kontor.Contacts.ContactEmbedding

    timestamps(type: :utc_datetime)
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:tenant_id, :email_address, :display_name, :organization, :role,
                    :profile_markdown, :importance_weight, :first_seen, :last_seen])
    |> validate_required([:tenant_id, :email_address])
    |> unique_constraint([:tenant_id, :email_address])
    |> validate_number(:importance_weight, greater_than_or_equal_to: 0.0)
  end
end
