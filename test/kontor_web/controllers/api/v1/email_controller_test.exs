defmodule KontorWeb.API.V1.EmailControllerTest do
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-email-ctrl-test"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/emails/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/emails/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id)

      conn = get(conn, ~p"/api/v1/emails/#{email.id}")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns email JSON when found", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id, subject: "Hello World")

      conn = authed_conn(conn) |> get(~p"/api/v1/emails/#{email.id}")
      body = json_response(conn, 200)

      assert body["email"]["id"] == email.id
      assert body["email"]["subject"] == "Hello World"
      assert body["email"]["sender"] == email.sender
      assert Map.has_key?(body["email"], "message_id")
      assert Map.has_key?(body["email"], "thread_id")
      assert Map.has_key?(body["email"], "recipients")
      assert Map.has_key?(body["email"], "received_at")
      assert Map.has_key?(body, "thread_markdown")
    end

    test "returns 404 when email does not exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/emails/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when email belongs to a different tenant", %{conn: conn} do
      other_user = insert(:user, tenant_id: "other-tenant")
      other_mailbox = insert(:mailbox, tenant_id: "other-tenant", user_id: other_user.id)
      email = insert(:email, tenant_id: "other-tenant", mailbox_id: other_mailbox.id)

      conn = authed_conn(conn) |> get(~p"/api/v1/emails/#{email.id}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
