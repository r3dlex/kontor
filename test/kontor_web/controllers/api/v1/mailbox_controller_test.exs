defmodule KontorWeb.API.V1.MailboxControllerTest do
  @moduledoc """
  Tests for MailboxController: index/2, show/2, create/2, update/2, delete/2.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-mailbox-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/mailboxes
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/mailboxes" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/mailboxes")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns empty list when no mailboxes exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/mailboxes")
      body = json_response(conn, 200)

      assert body["mailboxes"] == []
    end

    test "returns mailboxes for the authenticated tenant", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      conn = authed_conn(conn) |> get(~p"/api/v1/mailboxes")
      body = json_response(conn, 200)

      assert length(body["mailboxes"]) == 2
    end

    test "does not return mailboxes for other tenants", %{conn: conn} do
      insert(:mailbox, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> get(~p"/api/v1/mailboxes")
      body = json_response(conn, 200)

      assert body["mailboxes"] == []
    end

    test "mailbox JSON includes required fields", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      conn = authed_conn(conn) |> get(~p"/api/v1/mailboxes")
      [mailbox] = json_response(conn, 200)["mailboxes"]

      assert Map.has_key?(mailbox, "id")
      assert Map.has_key?(mailbox, "provider")
      assert Map.has_key?(mailbox, "email_address")
      assert Map.has_key?(mailbox, "polling_interval_seconds")
      assert Map.has_key?(mailbox, "read_only")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/mailboxes/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/mailboxes/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mb = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      conn = get(conn, ~p"/api/v1/mailboxes/#{mb.id}")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns mailbox JSON when found", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mb = insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      conn = authed_conn(conn) |> get(~p"/api/v1/mailboxes/#{mb.id}")
      body = json_response(conn, 200)

      assert body["mailbox"]["id"] == mb.id
      assert body["mailbox"]["email_address"] == mb.email_address
    end

    test "returns 404 when mailbox does not exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/mailboxes/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when mailbox belongs to a different tenant", %{conn: conn} do
      mb = insert(:mailbox, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> get(~p"/api/v1/mailboxes/#{mb.id}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/mailboxes
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/mailboxes" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/mailboxes", %{"provider" => "google"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "creates mailbox with valid params and returns 201", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)

      params = %{
        "provider" => "google",
        "email_address" => "new-box@example.com",
        "user_id" => user.id,
        "polling_interval_seconds" => 120,
        "task_age_cutoff_months" => 6,
        "read_only" => false
      }

      conn = authed_conn(conn) |> post(~p"/api/v1/mailboxes", params)
      body = json_response(conn, 201)

      assert body["mailbox"]["email_address"] == "new-box@example.com"
      assert Map.has_key?(body["mailbox"], "id")
    end

    test "returns 422 when required fields are missing", %{conn: conn} do
      conn = authed_conn(conn) |> post(~p"/api/v1/mailboxes", %{})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/mailboxes/:id
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/mailboxes/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mb = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      conn = put(conn, ~p"/api/v1/mailboxes/#{mb.id}", %{"read_only" => true})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "updates mailbox and returns updated JSON", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mb = insert(:mailbox, tenant_id: @tenant, user_id: user.id, polling_interval_seconds: 60)

      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/mailboxes/#{mb.id}", %{"polling_interval_seconds" => 300})

      body = json_response(conn, 200)
      assert body["mailbox"]["id"] == mb.id
      assert body["mailbox"]["polling_interval_seconds"] == 300
    end

    test "returns 404 when mailbox does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/mailboxes/#{Ecto.UUID.generate()}", %{"read_only" => true})

      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when mailbox belongs to a different tenant", %{conn: conn} do
      mb = insert(:mailbox, tenant_id: "other-tenant")

      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/mailboxes/#{mb.id}", %{"read_only" => true})

      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/mailboxes/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/mailboxes/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mb = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      conn = delete(conn, ~p"/api/v1/mailboxes/#{mb.id}")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "deletes mailbox and returns 204", %{conn: conn} do
      user = insert(:user, tenant_id: @tenant)
      mb = insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      conn = authed_conn(conn) |> delete(~p"/api/v1/mailboxes/#{mb.id}")
      assert response(conn, 204) == ""
    end

    test "returns 404 when mailbox does not exist", %{conn: conn} do
      conn = authed_conn(conn) |> delete(~p"/api/v1/mailboxes/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when mailbox belongs to a different tenant", %{conn: conn} do
      mb = insert(:mailbox, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> delete(~p"/api/v1/mailboxes/#{mb.id}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
