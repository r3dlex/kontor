defmodule Kontor.Chat.ChatSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_sessions" do
    field :tenant_id, :string
    field :view_origin, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :user, Kontor.Accounts.User

    has_many :messages, Kontor.Chat.ChatMessage, foreign_key: :session_id

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:tenant_id, :user_id, :view_origin, :started_at, :ended_at])
    |> validate_required([:tenant_id, :user_id])
  end
end
