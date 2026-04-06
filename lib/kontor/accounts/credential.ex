defmodule Kontor.Accounts.Credential do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "credentials" do
    field :tenant_id, :string
    field :provider, Ecto.Enum, values: [:google, :microsoft]
    field :access_token_encrypted, Kontor.Encrypted.Binary
    field :refresh_token_encrypted, Kontor.Encrypted.Binary
    field :expires_at, :utc_datetime

    belongs_to :user, Kontor.Accounts.User
    belongs_to :mailbox, Kontor.Accounts.Mailbox

    timestamps(type: :utc_datetime)
  end

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:tenant_id, :user_id, :mailbox_id, :provider,
                    :access_token_encrypted, :refresh_token_encrypted, :expires_at])
    |> validate_required([:tenant_id, :user_id, :provider])
  end

  def update_tokens(credential, access_token, refresh_token, expires_at) do
    credential
    |> change(%{
      access_token_encrypted: access_token,
      refresh_token_encrypted: refresh_token,
      expires_at: expires_at
    })
  end
end
