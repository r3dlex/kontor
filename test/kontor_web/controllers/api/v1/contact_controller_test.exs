defmodule KontorWeb.API.V1.ContactControllerTest do
  @moduledoc """
  Tests for ContactController: index/2, show/2, graph/2, refresh/2.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-contact-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/contacts
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/contacts" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/contacts")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns empty list when no contacts exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/contacts")
      body = json_response(conn, 200)

      assert body["contacts"] == []
    end

    test "returns contacts for the authenticated tenant", %{conn: conn} do
      insert(:contact, tenant_id: @tenant)
      insert(:contact, tenant_id: @tenant)
      insert(:contact, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> get(~p"/api/v1/contacts")
      body = json_response(conn, 200)

      assert length(body["contacts"]) == 2
    end

    test "contact JSON includes required fields", %{conn: conn} do
      insert(:contact, tenant_id: @tenant)

      conn = authed_conn(conn) |> get(~p"/api/v1/contacts")
      [contact] = json_response(conn, 200)["contacts"]

      assert Map.has_key?(contact, "id")
      assert Map.has_key?(contact, "email_address")
      assert Map.has_key?(contact, "display_name")
      assert Map.has_key?(contact, "organization")
      assert Map.has_key?(contact, "importance_weight")
    end

    test "supports limit and offset params", %{conn: conn} do
      # Use a unique tenant to avoid async test leakage
      unique_tenant = "tenant-contact-limit-#{System.unique_integer([:positive])}"
      user = insert(:user, tenant_id: unique_tenant)
      for _ <- 1..5, do: insert(:contact, tenant_id: unique_tenant)

      conn =
        authenticated_conn(conn, user.id, unique_tenant)
        |> get(~p"/api/v1/contacts", %{"limit" => "2", "offset" => "0"})

      body = json_response(conn, 200)
      assert length(body["contacts"]) == 2
    end

    test "supports filtering by organization", %{conn: conn} do
      insert(:contact, tenant_id: @tenant, organization: "ACME")
      insert(:contact, tenant_id: @tenant, organization: "Other Corp")

      conn =
        authed_conn(conn)
        |> get(~p"/api/v1/contacts", %{"organization" => "ACME"})

      body = json_response(conn, 200)
      assert length(body["contacts"]) == 1
      assert hd(body["contacts"])["organization"] == "ACME"
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/contacts/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/contacts/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      contact = insert(:contact, tenant_id: @tenant)
      conn = get(conn, ~p"/api/v1/contacts/#{contact.id}")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns contact JSON when found", %{conn: conn} do
      contact = insert(:contact, tenant_id: @tenant, display_name: "Alice")

      conn = authed_conn(conn) |> get(~p"/api/v1/contacts/#{contact.id}")
      body = json_response(conn, 200)

      assert body["contact"]["id"] == contact.id
      assert body["contact"]["display_name"] == "Alice"
    end

    test "returns 404 when contact does not exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/contacts/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when contact belongs to a different tenant", %{conn: conn} do
      contact = insert(:contact, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> get(~p"/api/v1/contacts/#{contact.id}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/contacts/graph
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/contacts/graph" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/contacts/graph")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns graph data with nodes and edges keys", %{conn: conn} do
      insert(:contact, tenant_id: @tenant)

      conn = authed_conn(conn) |> get(~p"/api/v1/contacts/graph")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "nodes")
      assert Map.has_key?(body, "edges")
    end

    test "returns empty graph when no contacts exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/contacts/graph")
      body = json_response(conn, 200)

      assert body["nodes"] == []
      assert body["edges"] == []
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/contacts/:id/refresh
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/contacts/:id/refresh" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      contact = insert(:contact, tenant_id: @tenant)
      conn = post(conn, ~p"/api/v1/contacts/#{contact.id}/refresh")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns 422 when contact does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> post(~p"/api/v1/contacts/#{Ecto.UUID.generate()}/refresh")

      assert json_response(conn, 422)
    end
  end
end
