defmodule Kontor.Chat do
  @moduledoc "Context module for chat sessions and messages."

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.Chat.{ChatSession, ChatMessage}

  def get_or_create_session(user_id, view_origin, tenant_id) do
    case Repo.one(
           from s in ChatSession,
           where: s.user_id == ^user_id and s.tenant_id == ^tenant_id and is_nil(s.ended_at),
           limit: 1
         ) do
      nil ->
        %ChatSession{}
        |> ChatSession.changeset(%{
          tenant_id: tenant_id,
          user_id: user_id,
          view_origin: view_origin,
          started_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.insert()
      session -> {:ok, session}
    end
  end

  def end_session(session_id, tenant_id) do
    case Repo.get_by(ChatSession, id: session_id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      session ->
        session
        |> ChatSession.changeset(%{ended_at: DateTime.utc_now() |> DateTime.truncate(:second)})
        |> Repo.update()
    end
  end

  def save_message(attrs, tenant_id) do
    %ChatMessage{}
    |> ChatMessage.changeset(Map.put(attrs, :tenant_id, tenant_id))
    |> Repo.insert()
  end

  def list_session_messages(session_id, tenant_id, limit \\ 50) do
    Repo.all(
      from m in ChatMessage,
      where: m.session_id == ^session_id and m.tenant_id == ^tenant_id,
      order_by: [asc: :inserted_at],
      limit: ^limit
    )
  end

  def recent_messages_for_context(session_id, tenant_id, limit \\ 20) do
    messages = list_session_messages(session_id, tenant_id, limit)
    Enum.map(messages, fn m ->
      %{"role" => Atom.to_string(m.role), "content" => m.content}
    end)
  end
end
