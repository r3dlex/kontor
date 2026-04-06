defmodule KontorWeb.API.V1.BackOfficeControllerTest do
  @moduledoc """
  Tests for BackOfficeController: index/2.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-backoffice-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/backoffice
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/backoffice" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/backoffice")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns backoffice dashboard data with date and meetings", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/backoffice")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "date")
      assert Map.has_key?(body, "meetings")
      assert is_list(body["meetings"])
    end

    test "returns empty meetings list when no events exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/backoffice")
      body = json_response(conn, 200)

      assert body["meetings"] == []
    end

    test "returns today's date in response", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/backoffice")
      body = json_response(conn, 200)

      today = Date.utc_today() |> Date.to_string()
      assert body["date"] == today
    end

    test "meeting JSON includes required fields when events exist", %{conn: conn} do
      insert(:calendar_event, tenant_id: @tenant)

      conn = authed_conn(conn) |> get(~p"/api/v1/backoffice")
      body = json_response(conn, 200)

      if length(body["meetings"]) > 0 do
        [meeting | _] = body["meetings"]
        assert Map.has_key?(meeting, "id")
        assert Map.has_key?(meeting, "title")
        assert Map.has_key?(meeting, "attendees")
      end
    end

    test "does not include events from other tenants", %{conn: conn} do
      insert(:calendar_event, tenant_id: "other-tenant", title: "Other Meeting")

      conn = authed_conn(conn) |> get(~p"/api/v1/backoffice")
      body = json_response(conn, 200)

      titles = Enum.map(body["meetings"], & &1["title"])
      refute "Other Meeting" in titles
    end
  end
end
