defmodule Kontor.Mail.Email do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "emails" do
    field :tenant_id, :string
    field :message_id, :string
    field :thread_id, :string
    field :subject, :string
    field :sender, :string
    field :recipients, {:array, :string}
    field :body, :string
    field :raw_headers, :map
    field :received_at, :utc_datetime
    field :processed_at, :utc_datetime

    belongs_to :mailbox, Kontor.Accounts.Mailbox

    timestamps(type: :utc_datetime)
  end

  def changeset(email, attrs) do
    email
    |> cast(attrs, [:tenant_id, :mailbox_id, :message_id, :thread_id, :subject,
                    :sender, :recipients, :body, :raw_headers, :received_at, :processed_at])
    |> validate_required([:tenant_id, :mailbox_id, :message_id])
    |> unique_constraint([:tenant_id, :message_id])
  end
end
