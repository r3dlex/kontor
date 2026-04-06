defmodule KontorWeb.NotificationsChannelTest do
  @moduledoc """
  Tests for NotificationsChannel: joining and receiving notification broadcasts.
  """
  use KontorWeb.ChannelCase, async: true

  @tenant "tenant-notifications-channel"

  defp connect_for(user) do
    connect_socket(user.id, user.tenant_id)
  end

  # ---------------------------------------------------------------------------
  # Join
  # ---------------------------------------------------------------------------

  describe "NotificationsChannel join" do
    test "succeeds when user_id in topic matches socket assignment" do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)

      assert {:ok, _, joined_socket} =
               subscribe_and_join(socket, "notifications:#{user.id}", %{})

      assert joined_socket.assigns.user_id == user.id
    end

    test "fails when user_id in topic differs from socket user_id" do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)

      other_id = Ecto.UUID.generate()

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, "notifications:#{other_id}", %{})
    end

    test "fails with an arbitrary non-matching topic" do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, "notifications:someone-else", %{})
    end
  end

  # ---------------------------------------------------------------------------
  # Broadcast events
  # ---------------------------------------------------------------------------

  describe "NotificationsChannel broadcasts" do
    setup do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)
      {:ok, _, joined_socket} = subscribe_and_join(socket, "notifications:#{user.id}", %{})
      {:ok, socket: joined_socket, user: user}
    end

    test "receives import_progress event when broadcast", %{user: user} do
      payload = %{processed: 10, total: 100}

      Phoenix.PubSub.broadcast(
        Kontor.PubSub,
        "notifications:#{user.id}",
        {:import_progress, payload}
      )

      assert_push "import_progress", ^payload
    end

    test "receives new_task event when broadcast", %{user: user} do
      task = insert(:task, tenant_id: user.tenant_id)

      expected = %{task_id: task.id, title: task.title}

      Phoenix.PubSub.broadcast(
        Kontor.PubSub,
        "notifications:#{user.id}",
        {:new_task, task}
      )

      assert_push "new_task", ^expected
    end

    test "receives calendar_update event when broadcast", %{user: user} do
      event = insert(:calendar_event, tenant_id: user.tenant_id)

      expected = %{event_id: event.id}

      Phoenix.PubSub.broadcast(
        Kontor.PubSub,
        "notifications:#{user.id}",
        {:calendar_update, event}
      )

      assert_push "calendar_update", ^expected
    end
  end
end
