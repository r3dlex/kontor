defmodule Kontor.ChatTest do
  use Kontor.DataCase, async: true

  alias Kontor.Chat

  @tenant "tenant-chat-test"

  defp create_user(tenant \\ @tenant) do
    insert(:user, tenant_id: tenant)
  end

  # ---------------------------------------------------------------------------
  # get_or_create_session/3
  # ---------------------------------------------------------------------------

  describe "get_or_create_session/3" do
    test "creates a new session when none exists" do
      user = create_user()
      assert {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)
      assert session.user_id == user.id
      assert session.tenant_id == @tenant
      assert session.view_origin == "inbox"
      assert is_nil(session.ended_at)
    end

    test "sets started_at on new session" do
      user = create_user()
      before = DateTime.utc_now() |> DateTime.truncate(:second)
      {:ok, session} = Chat.get_or_create_session(user.id, "tasks", @tenant)
      assert DateTime.compare(session.started_at, before) in [:gt, :eq]
    end

    test "returns existing open session regardless of view_origin" do
      user = create_user()
      {:ok, session1} = Chat.get_or_create_session(user.id, "inbox", @tenant)
      {:ok, session2} = Chat.get_or_create_session(user.id, "tasks", @tenant)
      assert session1.id == session2.id
    end

    test "creates new session after previous one is ended" do
      user = create_user()
      {:ok, session1} = Chat.get_or_create_session(user.id, "inbox", @tenant)
      Chat.end_session(session1.id, @tenant)

      {:ok, session2} = Chat.get_or_create_session(user.id, "inbox", @tenant)
      assert session1.id != session2.id
    end

    test "sessions are scoped per tenant — different tenants get different sessions" do
      tenant_a = "tenant-chat-a-#{System.unique_integer([:positive])}"
      tenant_b = "tenant-chat-b-#{System.unique_integer([:positive])}"
      user_a = create_user(tenant_a)
      user_b = create_user(tenant_b)

      {:ok, sa} = Chat.get_or_create_session(user_a.id, "inbox", tenant_a)
      {:ok, sb} = Chat.get_or_create_session(user_b.id, "inbox", tenant_b)

      assert sa.id != sb.id
      assert sa.tenant_id == tenant_a
      assert sb.tenant_id == tenant_b
    end
  end

  # ---------------------------------------------------------------------------
  # end_session/2
  # ---------------------------------------------------------------------------

  describe "end_session/2" do
    test "sets ended_at on the session" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      assert {:ok, ended} = Chat.end_session(session.id, @tenant)
      assert not is_nil(ended.ended_at)
    end

    test "ended_at is after started_at" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)
      {:ok, ended} = Chat.end_session(session.id, @tenant)

      assert DateTime.compare(ended.ended_at, session.started_at) in [:gt, :eq]
    end

    test "returns {:error, :not_found} for missing session" do
      assert {:error, :not_found} = Chat.end_session(Ecto.UUID.generate(), @tenant)
    end

    test "returns {:error, :not_found} for wrong tenant" do
      other_tenant = "other-end-tenant-#{System.unique_integer([:positive])}"
      user = create_user(other_tenant)
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", other_tenant)
      assert {:error, :not_found} = Chat.end_session(session.id, @tenant)
    end

    test "can end a session that was already ended (update is idempotent)" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)
      {:ok, _} = Chat.end_session(session.id, @tenant)
      # Second call should still succeed
      assert {:ok, _} = Chat.end_session(session.id, @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # save_message/2
  # ---------------------------------------------------------------------------

  describe "save_message/2" do
    test "saves a user message to a session" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      attrs = %{session_id: session.id, user_id: user.id, role: :user, content: "Hello!", view_context: %{}}
      assert {:ok, msg} = Chat.save_message(attrs, @tenant)
      assert msg.content == "Hello!"
      assert msg.role == :user
      assert msg.tenant_id == @tenant
    end

    test "saves an assistant message" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      attrs = %{session_id: session.id, user_id: user.id, role: :assistant, content: "I can help!", view_context: %{}}
      assert {:ok, msg} = Chat.save_message(attrs, @tenant)
      assert msg.role == :assistant
      assert msg.content == "I can help!"
    end

    test "saves message with view_context map" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      ctx = %{"thread_id" => "t1", "view" => "inbox"}
      attrs = %{session_id: session.id, user_id: user.id, role: :user, content: "Context msg", view_context: ctx}
      assert {:ok, msg} = Chat.save_message(attrs, @tenant)
      assert msg.view_context == ctx
    end

    test "returns error changeset when required fields are missing" do
      assert {:error, %Ecto.Changeset{}} = Chat.save_message(%{}, @tenant)
    end

    test "returns error changeset when content is missing" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      attrs = %{session_id: session.id, role: :user}
      assert {:error, changeset} = Chat.save_message(attrs, @tenant)
      assert %{content: [_|_]} = errors_on(changeset)
    end

    test "saves message with optional skill_invoked field" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      attrs = %{
        session_id: session.id,
        user_id: user.id,
        role: :assistant,
        content: "I ran task_extractor",
        view_context: %{},
        skill_invoked: "task_extractor"
      }
      assert {:ok, msg} = Chat.save_message(attrs, @tenant)
      assert msg.skill_invoked == "task_extractor"
    end
  end

  # ---------------------------------------------------------------------------
  # list_session_messages/3
  # ---------------------------------------------------------------------------

  describe "list_session_messages/3" do
    test "returns messages in chronological order" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      mk = fn content ->
        %{session_id: session.id, user_id: user.id, role: :user, content: content, view_context: %{}}
      end

      {:ok, _} = Chat.save_message(mk.("First"), @tenant)
      {:ok, _} = Chat.save_message(mk.("Second"), @tenant)
      {:ok, _} = Chat.save_message(mk.("Third"), @tenant)

      messages = Chat.list_session_messages(session.id, @tenant)
      assert length(messages) == 3
      assert Enum.map(messages, & &1.content) == ["First", "Second", "Third"]
    end

    test "respects limit parameter" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      Enum.each(1..5, fn i ->
        attrs = %{session_id: session.id, user_id: user.id, role: :user, content: "Msg #{i}", view_context: %{}}
        Chat.save_message(attrs, @tenant)
      end)

      results = Chat.list_session_messages(session.id, @tenant, 3)
      assert length(results) == 3
    end

    test "returns empty list for session with no messages" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)
      assert Chat.list_session_messages(session.id, @tenant) == []
    end

    test "does not return messages from other sessions" do
      user = create_user()
      {:ok, session1} = Chat.get_or_create_session(user.id, "inbox", @tenant)
      # End it so we can create a second session
      Chat.end_session(session1.id, @tenant)
      {:ok, session2} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      attrs = %{session_id: session1.id, user_id: user.id, role: :user, content: "From session 1", view_context: %{}}
      Chat.save_message(attrs, @tenant)

      assert Chat.list_session_messages(session2.id, @tenant) == []
    end

    test "does not return messages from other tenants" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      attrs = %{session_id: session.id, user_id: user.id, role: :user, content: "My message", view_context: %{}}
      Chat.save_message(attrs, @tenant)

      other_tenant = "totally-different-#{System.unique_integer([:positive])}"
      assert Chat.list_session_messages(session.id, other_tenant) == []
    end

    test "default limit is 50" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      Enum.each(1..10, fn i ->
        attrs = %{session_id: session.id, user_id: user.id, role: :user, content: "Msg #{i}", view_context: %{}}
        Chat.save_message(attrs, @tenant)
      end)

      results = Chat.list_session_messages(session.id, @tenant)
      assert length(results) == 10
    end
  end

  # ---------------------------------------------------------------------------
  # recent_messages_for_context/3
  # ---------------------------------------------------------------------------

  describe "recent_messages_for_context/3" do
    test "returns messages as role/content string maps" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      attrs = %{session_id: session.id, user_id: user.id, role: :user, content: "Hello", view_context: %{}}
      Chat.save_message(attrs, @tenant)

      messages = Chat.recent_messages_for_context(session.id, @tenant)
      assert [%{"role" => "user", "content" => "Hello"}] = messages
    end

    test "converts role atom to string" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      Chat.save_message(%{session_id: session.id, user_id: user.id, role: :assistant, content: "Hi", view_context: %{}}, @tenant)

      [msg] = Chat.recent_messages_for_context(session.id, @tenant)
      assert msg["role"] == "assistant"
      assert is_binary(msg["role"])
    end

    test "returns empty list for session with no messages" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)
      assert Chat.recent_messages_for_context(session.id, @tenant) == []
    end

    test "returns multiple messages in order" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      Chat.save_message(%{session_id: session.id, user_id: user.id, role: :user, content: "Q1", view_context: %{}}, @tenant)
      Chat.save_message(%{session_id: session.id, user_id: user.id, role: :assistant, content: "A1", view_context: %{}}, @tenant)

      messages = Chat.recent_messages_for_context(session.id, @tenant)
      assert length(messages) == 2
      assert Enum.at(messages, 0)["role"] == "user"
      assert Enum.at(messages, 1)["role"] == "assistant"
    end

    test "respects limit parameter" do
      user = create_user()
      {:ok, session} = Chat.get_or_create_session(user.id, "inbox", @tenant)

      Enum.each(1..10, fn i ->
        Chat.save_message(%{session_id: session.id, user_id: user.id, role: :user, content: "M#{i}", view_context: %{}}, @tenant)
      end)

      messages = Chat.recent_messages_for_context(session.id, @tenant, 4)
      assert length(messages) == 4
    end
  end
end
