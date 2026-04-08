defmodule KontorWeb.API.V1.FolderCorrectionControllerTest do
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-folder-correction-ctrl"

  defp authed_conn(conn, user) do
    authenticated_conn(conn, user.id, @tenant)
  end

  describe "POST /api/v1/mailboxes/:mailbox_id/folder_corrections" do
    test "creates a folder correction and returns 201", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
                      message_id: "ctrl-test-#{System.unique_integer([:positive])}")

      params = %{
        email_id: email.id,
        from_folder: "Inbox",
        to_folder: "Archive",
        sender: "sender@example.com",
        sender_domain: "example.com"
      }

      response =
        authed_conn(conn, user)
        |> post(~p"/api/v1/mailboxes/#{mailbox.id}/folder_corrections", params)
        |> json_response(201)

      assert response["data"]["id"]
    end

    test "returns 401 when unauthenticated", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      conn
      |> post(~p"/api/v1/mailboxes/#{mailbox.id}/folder_corrections", %{})
      |> json_response(401)
    end

    test "returns 422 when email_id is missing", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      params = %{
        from_folder: "Inbox",
        to_folder: "Archive"
      }

      authed_conn(conn, user)
      |> post(~p"/api/v1/mailboxes/#{mailbox.id}/folder_corrections", params)
      |> json_response(422)
    end
  end
end
