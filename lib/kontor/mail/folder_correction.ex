defmodule Kontor.Mail.FolderCorrection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "folder_corrections" do
    field :tenant_id, :string
    field :from_folder, :string
    field :to_folder, :string
    field :sender, :string
    field :sender_domain, :string
    field :recorded_at, :utc_datetime

    belongs_to :mailbox, Kontor.Accounts.Mailbox
    belongs_to :email, Kontor.Mail.Email
  end

  def changeset(folder_correction, attrs) do
    folder_correction
    |> cast(attrs, [:tenant_id, :mailbox_id, :email_id, :from_folder, :to_folder,
                    :sender, :sender_domain, :recorded_at])
    |> validate_required([:tenant_id, :mailbox_id, :email_id])
    |> foreign_key_constraint(:mailbox_id)
    |> foreign_key_constraint(:email_id)
  end
end
