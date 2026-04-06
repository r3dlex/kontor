defmodule KontorWeb.ContactsChannelTest do
  @moduledoc """
  Tests for ContactsChannel: joining and receiving contact broadcast events.
  """
  use KontorWeb.ChannelCase, async: true

  @tenant "tenant-contacts-channel"

  defp connect_for(user) do
    connect_socket(user.id, user.tenant_id)
  end

  # ---------------------------------------------------------------------------
  # Join
  # ---------------------------------------------------------------------------

  describe "ContactsChannel join" do
    test "succeeds when user_id in topic matches socket assignment" do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)

      assert {:ok, _, joined_socket} =
               subscribe_and_join(socket, "contacts:#{user.id}", %{})

      assert joined_socket.assigns.user_id == user.id
    end

    test "fails when user_id in topic differs from socket user_id" do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)

      other_id = Ecto.UUID.generate()

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, "contacts:#{other_id}", %{})
    end

    test "fails with an arbitrary non-matching topic" do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, "contacts:someone-else", %{})
    end
  end

  # ---------------------------------------------------------------------------
  # Broadcast events
  # ---------------------------------------------------------------------------

  describe "ContactsChannel broadcasts" do
    setup do
      user = insert(:user, tenant_id: @tenant)
      socket = connect_for(user)
      {:ok, _, joined_socket} = subscribe_and_join(socket, "contacts:#{user.id}", %{})
      {:ok, socket: joined_socket, user: user}
    end

    test "receives contact_updated event when broadcast on tenant topic", %{user: user} do
      contact = insert(:contact, tenant_id: user.tenant_id)

      expected = %{contact_id: contact.id}

      Phoenix.PubSub.broadcast(
        Kontor.PubSub,
        "contacts:#{user.tenant_id}",
        {:contact_updated, contact}
      )

      assert_push "contact_updated", ^expected
    end

    test "receives graph_updated event when broadcast on tenant topic", %{user: user} do
      Phoenix.PubSub.broadcast(
        Kontor.PubSub,
        "contacts:#{user.tenant_id}",
        {:graph_updated}
      )

      assert_push "graph_updated", %{}
    end
  end
end
