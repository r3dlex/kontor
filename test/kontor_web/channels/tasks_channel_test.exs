defmodule KontorWeb.TasksChannelTest do
  @moduledoc """
  Tests for TasksChannel: joining and receiving task broadcast events.
  """
  use KontorWeb.ChannelCase, async: true

  alias KontorWeb.UserSocket

  @tenant "tenant-tasks-channel"

  defp connect_for(user) do
    connect_socket(user.id, user.tenant_id)
  end

  # ---------------------------------------------------------------------------
  # Join
  # ---------------------------------------------------------------------------

  describe "TasksChannel join" do
    test "succeeds when user_id in topic matches socket assignment" do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)

      assert {:ok, _, joined_socket} =
               subscribe_and_join(socket, "tasks:#{user.id}", %{})

      assert joined_socket.assigns.user_id == user.id
    end

    test "fails when user_id in topic differs from socket user_id" do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)

      other_id = Ecto.UUID.generate()

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, "tasks:#{other_id}", %{})
    end

    test "fails with an arbitrary non-matching topic" do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, "tasks:someone-else", %{})
    end
  end

  # ---------------------------------------------------------------------------
  # Broadcast events
  # ---------------------------------------------------------------------------

  describe "TasksChannel broadcasts" do
    setup do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)
      {:ok, _, joined_socket} = subscribe_and_join(socket, "tasks:#{user.id}", %{})
      {:ok, socket: joined_socket, user: user}
    end

    test "receives task_created event when broadcast on tenant topic", %{socket: socket, user: user} do
      task = insert(:task, tenant_id: user.tenant_id)

      broadcast_payload = %{
        id: task.id,
        title: task.title,
        status: task.status,
        task_type: task.task_type,
        importance: task.importance,
        confidence: task.confidence
      }

      Phoenix.PubSub.broadcast(
        Kontor.PubSub,
        "tasks:#{user.tenant_id}",
        {:task_created, task}
      )

      assert_push "task_created", ^broadcast_payload
    end

    test "receives task_updated event when broadcast on tenant topic", %{socket: socket, user: user} do
      task = insert(:task, tenant_id: user.tenant_id)

      broadcast_payload = %{
        id: task.id,
        title: task.title,
        status: task.status,
        task_type: task.task_type,
        importance: task.importance,
        confidence: task.confidence
      }

      Phoenix.PubSub.broadcast(
        Kontor.PubSub,
        "tasks:#{user.tenant_id}",
        {:task_updated, task}
      )

      assert_push "task_updated", ^broadcast_payload
    end
  end
end
