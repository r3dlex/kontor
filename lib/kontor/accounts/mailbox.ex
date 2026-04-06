defmodule Kontor.Accounts.Mailbox do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mailboxes" do
    field :tenant_id, :string
    field :provider, Ecto.Enum, values: [:google, :microsoft]
    field :email_address, :string
    field :himalaya_config, :map
    field :polling_interval_seconds, :integer, default: 60
    field :task_age_cutoff_months, :integer, default: 3
    field :read_only, :boolean, default: false

    belongs_to :user, Kontor.Accounts.User
    has_one :credential, Kontor.Accounts.Credential
    has_many :emails, Kontor.Mail.Email

    timestamps(type: :utc_datetime)
  end

  def changeset(mailbox, attrs) do
    mailbox
    |> cast(attrs, [:tenant_id, :user_id, :provider, :email_address, :himalaya_config,
                    :polling_interval_seconds, :task_age_cutoff_months, :read_only])
    |> validate_required([:tenant_id, :user_id, :provider, :email_address])
    |> validate_inclusion(:provider, [:google, :microsoft])
    |> unique_constraint(:email_address, name: :mailboxes_tenant_id_email_address_index)
  end
end
