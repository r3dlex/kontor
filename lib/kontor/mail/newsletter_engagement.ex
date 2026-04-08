defmodule Kontor.Mail.NewsletterEngagement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "newsletter_engagement" do
    field :tenant_id, :string
    field :sender_domain, :string
    field :consecutive_unread, :integer, default: 0
    field :last_received_at, :utc_datetime
    field :auto_archive, :boolean, default: false

    belongs_to :mailbox, Kontor.Accounts.Mailbox
    timestamps(type: :utc_datetime)
  end

  def changeset(engagement, attrs) do
    engagement
    |> cast(attrs, [:tenant_id, :mailbox_id, :sender_domain, :consecutive_unread,
                    :last_received_at, :auto_archive])
    |> validate_required([:tenant_id, :mailbox_id, :sender_domain])
    |> foreign_key_constraint(:mailbox_id)
  end
end
