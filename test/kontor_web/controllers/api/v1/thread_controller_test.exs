defmodule KontorWeb.API.V1.ThreadControllerTest do
  @moduledoc """
  Tests for ThreadController show/2 and update/2 actions.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-thread-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/threads/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/threads/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      thread = insert(:thread, tenant_id: @tenant)
      conn = get(conn, ~p"/api/v1/threads/#{thread.id}")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns thread JSON when found", %{conn: conn} do
      thread = insert(:thread, tenant_id: @tenant)

      conn = authed_conn(conn) |> get(~p"/api/v1/threads/#{thread.id}")
      body = json_response(conn, 200)

      assert body["thread"]["id"] == thread.id
      assert body["thread"]["thread_id"] == thread.thread_id
      assert Map.has_key?(body["thread"], "markdown_content")
      assert Map.has_key?(body["thread"], "composite_score")
      assert Map.has_key?(body["thread"], "score_urgency")
      assert Map.has_key?(body["thread"], "score_action")
      assert Map.has_key?(body["thread"], "score_authority")
      assert Map.has_key?(body["thread"], "score_momentum")
    end

    test "returns 404 when thread does not exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/threads/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when thread belongs to a different tenant", %{conn: conn} do
      thread = insert(:thread, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> get(~p"/api/v1/threads/#{thread.id}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/threads/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/threads/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      thread = insert(:thread, tenant_id: @tenant)
      conn = patch(conn, ~p"/api/v1/threads/#{thread.id}", %{"markdown_content" => "new"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "updates markdown_content and returns updated thread", %{conn: conn} do
      thread = insert(:thread, tenant_id: @tenant, markdown_content: "# Old")

      conn =
        authed_conn(conn)
        |> patch(~p"/api/v1/threads/#{thread.id}", %{"markdown_content" => "# New"})

      body = json_response(conn, 200)
      assert body["thread"]["markdown_content"] == "# New"
      assert body["thread"]["id"] == thread.id
    end

    test "updates score fields and returns updated thread", %{conn: conn} do
      thread = insert(:thread, tenant_id: @tenant)

      conn =
        authed_conn(conn)
        |> patch(~p"/api/v1/threads/#{thread.id}", %{
          "score_urgency" => 0.9,
          "score_action" => 0.8,
          "score_authority" => 0.7,
          "score_momentum" => 0.6
        })

      body = json_response(conn, 200)
      assert body["thread"]["score_urgency"] == 0.9
      assert body["thread"]["score_action"] == 0.8
    end

    test "returns 404 when thread does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> patch(~p"/api/v1/threads/#{Ecto.UUID.generate()}", %{"markdown_content" => "x"})

      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when thread belongs to a different tenant", %{conn: conn} do
      thread = insert(:thread, tenant_id: "other-tenant")

      conn =
        authed_conn(conn)
        |> patch(~p"/api/v1/threads/#{thread.id}", %{"markdown_content" => "x"})

      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
