defmodule Kontor.Contacts.ContactMailboxContext do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contact_mailbox_contexts" do
    field :tenant_id, :string
    field :context_role, :string
    field :interaction_frequency, :integer, default: 0
    field :avg_response_time_hours, :float
    field :topics, :map, default: %{}
    field :last_interaction, :utc_datetime

    belongs_to :contact, Kontor.Contacts.Contact
    belongs_to :mailbox, Kontor.Accounts.Mailbox

    timestamps(type: :utc_datetime)
  end

  def changeset(ctx, attrs) do
    ctx
    |> cast(attrs, [:tenant_id, :contact_id, :mailbox_id, :context_role,
                    :interaction_frequency, :avg_response_time_hours, :topics, :last_interaction])
    |> validate_required([:tenant_id, :contact_id, :mailbox_id])
    |> unique_constraint([:contact_id, :mailbox_id])
  end
end
