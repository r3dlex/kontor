defmodule Kontor.Mail.ScheduledSend do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "scheduled_sends" do
    field :tenant_id, :string
    field :draft_content, :string
    field :recipients, {:array, :string}
    field :subject, :string
    field :scheduled_at, :utc_datetime
    field :status, Ecto.Enum, values: [:pending, :sent, :cancelled], default: :pending
    field :sent_at, :utc_datetime

    belongs_to :mailbox, Kontor.Accounts.Mailbox

    timestamps(type: :utc_datetime)
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [:tenant_id, :mailbox_id, :draft_content, :recipients,
                    :subject, :scheduled_at, :status, :sent_at])
    |> validate_required([:tenant_id, :mailbox_id, :draft_content, :recipients, :scheduled_at])
  end
end
