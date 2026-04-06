defmodule KontorWeb.API.V1.DraftControllerTest do
  @moduledoc """
  Tests for DraftController: index/2, create/2, send_draft/2.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-draft-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  defp mailbox_id do
    user = insert(:user, tenant_id: @tenant)
    mb = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
    mb.id
  end

  defp valid_draft_params(mb_id) do
    %{
      "subject" => "Test Subject",
      "recipients" => ["bob@example.com"],
      "draft_content" => "Hello Bob",
      "mailbox_id" => mb_id,
      "scheduled_at" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_iso8601()
    }
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/drafts
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/drafts" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/drafts")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns empty list when no drafts exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/drafts")
      body = json_response(conn, 200)

      assert body["drafts"] == []
    end

    test "returns pending drafts for the authenticated tenant", %{conn: conn} do
      mb_id = mailbox_id()
      Kontor.Mail.create_draft(valid_draft_params(mb_id), @tenant)

      conn = authed_conn(conn) |> get(~p"/api/v1/drafts")
      body = json_response(conn, 200)

      assert length(body["drafts"]) >= 1
    end

    test "draft JSON includes required fields", %{conn: conn} do
      mb_id = mailbox_id()
      Kontor.Mail.create_draft(valid_draft_params(mb_id), @tenant)

      conn = authed_conn(conn) |> get(~p"/api/v1/drafts")
      drafts = json_response(conn, 200)["drafts"]
      assert length(drafts) >= 1
      [draft | _] = drafts

      assert Map.has_key?(draft, "id")
      assert Map.has_key?(draft, "subject")
      assert Map.has_key?(draft, "draft_content")
      assert Map.has_key?(draft, "recipients")
      assert Map.has_key?(draft, "status")
      assert Map.has_key?(draft, "inserted_at")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/drafts
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/drafts" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/drafts", %{
          "subject" => "S",
          "recipients" => ["a@b.com"],
          "draft_content" => "body"
        })

      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "creates draft with valid params and returns 201", %{conn: conn} do
      mb_id = mailbox_id()
      params = valid_draft_params(mb_id) |> Map.put("subject", "New Draft")

      conn = authed_conn(conn) |> post(~p"/api/v1/drafts", params)
      body = json_response(conn, 201)

      assert body["draft"]["subject"] == "New Draft"
      assert Map.has_key?(body["draft"], "id")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/drafts/:id/send
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/drafts/:id/send" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      mb_id = mailbox_id()
      {:ok, draft} = Kontor.Mail.create_draft(valid_draft_params(mb_id), @tenant)

      conn = post(conn, ~p"/api/v1/drafts/#{draft.id}/send")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns scheduled status when scheduled_at is provided", %{conn: conn} do
      mb_id = mailbox_id()
      {:ok, draft} = Kontor.Mail.create_draft(valid_draft_params(mb_id), @tenant)

      future = DateTime.utc_now() |> DateTime.add(7200) |> DateTime.to_iso8601()

      conn =
        authed_conn(conn)
        |> post(~p"/api/v1/drafts/#{draft.id}/send", %{"scheduled_at" => future})

      body = json_response(conn, 200)
      assert body["status"] == "scheduled"
    end

    test "returns 422 when draft does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> post(~p"/api/v1/drafts/#{Ecto.UUID.generate()}/send")

      assert json_response(conn, 422)
    end
  end
end
