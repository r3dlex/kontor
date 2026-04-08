defmodule KontorWeb.API.V1.EmailLabelControllerTest do
  use KontorWeb.ConnCase, async: true

  alias Kontor.Mail

  @tenant "tenant-email-label-ctrl"

  defp authed_conn(conn, user) do
    authenticated_conn(conn, user.id, @tenant)
  end

  describe "GET /api/v1/emails/:email_id/labels" do
    test "returns labels for an email", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
                      message_id: "label-ctrl-#{System.unique_integer([:positive])}")

      {:ok, _} = Mail.upsert_email_labels(%{
        email_id: email.id,
        labels: ["Direct", "VIP"],
        priority_score: 80,
        has_actionable_task: true,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }, @tenant)

      response =
        authed_conn(conn, user)
        |> get(~p"/api/v1/emails/#{email.id}/labels")
        |> json_response(200)

      assert response["data"]["labels"] == ["Direct", "VIP"]
      assert response["data"]["priority_score"] == 80
    end

    test "returns 404 when no labels exist", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
                      message_id: "no-label-#{System.unique_integer([:positive])}")

      authed_conn(conn, user)
      |> get(~p"/api/v1/emails/#{email.id}/labels")
      |> json_response(404)
    end

    test "returns 401 when unauthenticated", %{conn: conn} do
      conn
      |> get(~p"/api/v1/emails/#{Ecto.UUID.generate()}/labels")
      |> json_response(401)
    end
  end
end
