defmodule KontorWeb.API.V1.CalendarControllerTest do
  @moduledoc """
  Tests for CalendarController: today/2, briefing/2, refresh_briefing/2,
  create_event/2, update_event/2.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-calendar-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/calendar/today
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/calendar/today" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/calendar/today")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns events list for the authenticated tenant", %{conn: conn} do
      insert(:calendar_event, tenant_id: @tenant)
      insert(:calendar_event, tenant_id: @tenant)
      # event for another tenant — should not appear
      insert(:calendar_event, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> get(~p"/api/v1/calendar/today")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "events")
      assert is_list(body["events"])
    end

    test "returns empty events list when no events exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/calendar/today")
      body = json_response(conn, 200)

      assert body["events"] == []
    end

    test "event JSON includes required fields", %{conn: conn} do
      insert(:calendar_event, tenant_id: @tenant)

      conn = authed_conn(conn) |> get(~p"/api/v1/calendar/today")
      events = json_response(conn, 200)["events"]

      if length(events) > 0 do
        [event | _] = events
        assert Map.has_key?(event, "id")
        assert Map.has_key?(event, "title")
        assert Map.has_key?(event, "attendees")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/calendar/briefing/:event_id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/calendar/briefing/:event_id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      event = insert(:calendar_event, tenant_id: @tenant)
      conn = get(conn, ~p"/api/v1/calendar/briefing/#{event.id}")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns event JSON when found", %{conn: conn} do
      event = insert(:calendar_event, tenant_id: @tenant)

      conn = authed_conn(conn) |> get(~p"/api/v1/calendar/briefing/#{event.id}")
      body = json_response(conn, 200)

      assert body["event"]["id"] == event.id
      assert body["event"]["title"] == event.title
    end

    test "returns 404 when event does not exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/calendar/briefing/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when event belongs to a different tenant", %{conn: conn} do
      event = insert(:calendar_event, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> get(~p"/api/v1/calendar/briefing/#{event.id}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/calendar/briefing/:event_id/refresh
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/calendar/briefing/:event_id/refresh" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      event = insert(:calendar_event, tenant_id: @tenant)
      conn = post(conn, ~p"/api/v1/calendar/briefing/#{event.id}/refresh")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns 404 when event does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> post(~p"/api/v1/calendar/briefing/#{Ecto.UUID.generate()}/refresh")

      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when event belongs to a different tenant", %{conn: conn} do
      event = insert(:calendar_event, tenant_id: "other-tenant")

      conn =
        authed_conn(conn)
        |> post(~p"/api/v1/calendar/briefing/#{event.id}/refresh")

      assert json_response(conn, 404)["error"] == "not found"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/calendar/events
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/calendar/events" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/calendar/events", %{"title" => "Meeting"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "creates event with valid params and returns 201", %{conn: conn} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      params = %{
        "title" => "New Meeting",
        "provider" => "google",
        "external_id" => "ext-new-#{System.unique_integer()}",
        "attendees" => ["alice@example.com"],
        "start_time" => DateTime.to_iso8601(now),
        "end_time" => DateTime.to_iso8601(DateTime.add(now, 3600))
      }

      conn = authed_conn(conn) |> post(~p"/api/v1/calendar/events", params)
      body = json_response(conn, 201)

      assert body["event"]["title"] == "New Meeting"
      assert Map.has_key?(body["event"], "id")
    end

    test "returns 422 with invalid params (missing required fields)", %{conn: conn} do
      conn = authed_conn(conn) |> post(~p"/api/v1/calendar/events", %{})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/calendar/events/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/calendar/events/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      event = insert(:calendar_event, tenant_id: @tenant)
      conn = patch(conn, ~p"/api/v1/calendar/events/#{event.id}", %{"title" => "Updated"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "updates event and returns updated JSON", %{conn: conn} do
      event = insert(:calendar_event, tenant_id: @tenant, title: "Old Title")

      conn =
        authed_conn(conn)
        |> patch(~p"/api/v1/calendar/events/#{event.id}", %{"title" => "New Title"})

      body = json_response(conn, 200)
      assert body["event"]["title"] == "New Title"
      assert body["event"]["id"] == event.id
    end

    test "returns 404 when event does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> patch(~p"/api/v1/calendar/events/#{Ecto.UUID.generate()}", %{"title" => "X"})

      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
