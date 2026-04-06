defmodule Kontor.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :tenant_id, :string
    field :email, :string
    field :name, :string
    field :preferences_md_path, :string

    has_many :mailboxes, Kontor.Accounts.Mailbox
    has_many :credentials, Kontor.Accounts.Credential
    has_many :chat_sessions, Kontor.Chat.ChatSession

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:tenant_id, :email, :name, :preferences_md_path])
    |> validate_required([:tenant_id, :email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> unique_constraint([:tenant_id, :email])
  end
end
