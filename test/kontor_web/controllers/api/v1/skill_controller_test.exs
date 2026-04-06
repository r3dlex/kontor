defmodule KontorWeb.API.V1.SkillControllerTest do
  @moduledoc """
  Tests for SkillController: index/2, show/2, update/2, execute/2.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-skill-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/skills
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/skills" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/skills")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns empty skills list when no skills exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/skills")
      body = json_response(conn, 200)

      assert body["skills"] == []
    end

    test "returns skills for the authenticated tenant", %{conn: conn} do
      insert(:skill, tenant_id: @tenant, name: "skill-a", active: true)
      insert(:skill, tenant_id: @tenant, name: "skill-b", active: true)
      insert(:skill, tenant_id: "other-tenant", name: "other-skill", active: true)

      conn = authed_conn(conn) |> get(~p"/api/v1/skills")
      body = json_response(conn, 200)

      assert length(body["skills"]) == 2
    end

    test "skill JSON includes required fields", %{conn: conn} do
      insert(:skill, tenant_id: @tenant, name: "field-check-skill", active: true)

      conn = authed_conn(conn) |> get(~p"/api/v1/skills")
      [skill] = json_response(conn, 200)["skills"]

      assert Map.has_key?(skill, "id")
      assert Map.has_key?(skill, "name")
      assert Map.has_key?(skill, "namespace")
      assert Map.has_key?(skill, "version")
      assert Map.has_key?(skill, "author")
      assert Map.has_key?(skill, "locked")
      assert Map.has_key?(skill, "active")
    end

    test "does not return inactive skills", %{conn: conn} do
      insert(:skill, tenant_id: @tenant, name: "active-skill", active: true)
      insert(:skill, tenant_id: @tenant, name: "inactive-skill", active: false)

      conn = authed_conn(conn) |> get(~p"/api/v1/skills")
      body = json_response(conn, 200)

      assert length(body["skills"]) == 1
      assert hd(body["skills"])["name"] == "active-skill"
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/skills/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/skills/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      skill = insert(:skill, tenant_id: @tenant)
      conn = get(conn, ~p"/api/v1/skills/#{skill.id}")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns skill JSON when found", %{conn: conn} do
      skill = insert(:skill, tenant_id: @tenant, name: "found-skill")

      conn = authed_conn(conn) |> get(~p"/api/v1/skills/#{skill.id}")
      body = json_response(conn, 200)

      assert body["skill"]["id"] == skill.id
      assert body["skill"]["name"] == "found-skill"
    end

    test "returns 404 when skill does not exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/skills/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when skill belongs to a different tenant", %{conn: conn} do
      skill = insert(:skill, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> get(~p"/api/v1/skills/#{skill.id}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/skills/:id
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/skills/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      skill = insert(:skill, tenant_id: @tenant)
      conn = put(conn, ~p"/api/v1/skills/#{skill.id}", %{"content" => "new content"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "updates skill and returns updated JSON", %{conn: conn} do
      skill = insert(:skill, tenant_id: @tenant, name: "update-skill", content: "old")

      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/skills/#{skill.id}", %{"content" => "updated content"})

      body = json_response(conn, 200)
      assert body["skill"]["id"] == skill.id
    end

    test "returns 404 when skill does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/skills/#{Ecto.UUID.generate()}", %{"content" => "x"})

      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when skill belongs to a different tenant", %{conn: conn} do
      skill = insert(:skill, tenant_id: "other-tenant")

      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/skills/#{skill.id}", %{"content" => "x"})

      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/skills/:id/execute
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/skills/:id/execute" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      skill = insert(:skill, tenant_id: @tenant)
      conn = post(conn, ~p"/api/v1/skills/#{skill.id}/execute", %{})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns 404 when skill does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> post(~p"/api/v1/skills/#{Ecto.UUID.generate()}/execute", %{})

      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when skill belongs to a different tenant", %{conn: conn} do
      skill = insert(:skill, tenant_id: "other-tenant")

      conn =
        authed_conn(conn)
        |> post(~p"/api/v1/skills/#{skill.id}/execute", %{})

      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
