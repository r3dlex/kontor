defmodule Kontor.Mail.FolderSuggestion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "folder_suggestions" do
    field :tenant_id, :string
    field :email_message_id, :string
    field :suggested_folder, :string
    field :current_folder, :string
    field :create_if_missing, :boolean, default: false
    field :status, :string, default: "pending"
    field :confidence, :float
    field :inserted_at, :utc_datetime

    belongs_to :mailbox, Kontor.Accounts.Mailbox
    belongs_to :email, Kontor.Mail.Email
  end

  @valid_statuses ~w(pending applied skipped_bootstrap failed)

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [:tenant_id, :mailbox_id, :email_id, :email_message_id,
                    :suggested_folder, :current_folder, :create_if_missing,
                    :status, :confidence])
    |> validate_required([:tenant_id, :mailbox_id, :email_id, :email_message_id,
                          :suggested_folder, :status, :confidence])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end
end
