defmodule Kontor.Chat.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_messages" do
    field :tenant_id, :string
    field :role, Ecto.Enum, values: [:user, :assistant]
    field :content, :string
    field :view_context, :map, default: %{}
    field :thread_id, :binary_id
    field :task_id, :binary_id
    field :skill_invoked, :string

    belongs_to :session, Kontor.Chat.ChatSession
    belongs_to :user, Kontor.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(msg, attrs) do
    msg
    |> cast(attrs, [:tenant_id, :session_id, :user_id, :role, :content,
                    :view_context, :thread_id, :task_id, :skill_invoked])
    |> validate_required([:tenant_id, :session_id, :role, :content])
  end
end
