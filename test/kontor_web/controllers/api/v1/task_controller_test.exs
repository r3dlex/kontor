defmodule KontorWeb.API.V1.TaskControllerTest do
  use KontorWeb.ConnCase, async: true

  alias Kontor.Tasks

  @tenant "tenant-task-ctrl-test"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/tasks
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/tasks" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tasks")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns empty tasks list when no tasks exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/tasks")
      assert %{"tasks" => []} = json_response(conn, 200)
    end

    test "returns all tasks for the authenticated tenant", %{conn: conn} do
      insert(:task, tenant_id: @tenant, title: "Task One")
      insert(:task, tenant_id: @tenant, title: "Task Two")

      conn = authed_conn(conn) |> get(~p"/api/v1/tasks")
      body = json_response(conn, 200)

      assert length(body["tasks"]) == 2
    end

    test "does not return tasks for other tenants", %{conn: conn} do
      insert(:task, tenant_id: "other-tenant", title: "Other task")

      conn = authed_conn(conn) |> get(~p"/api/v1/tasks")
      body = json_response(conn, 200)

      assert body["tasks"] == []
    end

    test "filters tasks by status when status param provided", %{conn: conn} do
      insert(:task, tenant_id: @tenant, status: :confirmed, title: "Confirmed")
      insert(:task, tenant_id: @tenant, status: :created, title: "Created")

      conn = authed_conn(conn) |> get(~p"/api/v1/tasks", %{"status" => "confirmed"})
      body = json_response(conn, 200)

      assert length(body["tasks"]) == 1
      assert hd(body["tasks"])["status"] == "confirmed"
    end

    test "returns all tasks when no status filter provided", %{conn: conn} do
      insert(:task, tenant_id: @tenant, status: :confirmed, title: "Confirmed")
      insert(:task, tenant_id: @tenant, status: :done, title: "Done")

      conn = authed_conn(conn) |> get(~p"/api/v1/tasks")
      body = json_response(conn, 200)

      assert length(body["tasks"]) == 2
    end

    test "task JSON includes required fields", %{conn: conn} do
      insert(:task, tenant_id: @tenant, title: "Field check task",
             task_type: :reply, importance: 0.7)

      conn = authed_conn(conn) |> get(~p"/api/v1/tasks")
      [task] = json_response(conn, 200)["tasks"]

      assert Map.has_key?(task, "id")
      assert Map.has_key?(task, "task_type")
      assert Map.has_key?(task, "title")
      assert Map.has_key?(task, "description")
      assert Map.has_key?(task, "importance")
      assert Map.has_key?(task, "status")
      assert Map.has_key?(task, "confidence")
      assert Map.has_key?(task, "inserted_at")
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/tasks/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/tasks/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      task = insert(:task, tenant_id: @tenant)
      conn = patch(conn, ~p"/api/v1/tasks/#{task.id}", %{"status" => "done"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "updates task status and returns 200 with task JSON", %{conn: conn} do
      task = insert(:task, tenant_id: @tenant, status: :created)

      conn = authed_conn(conn)
             |> patch(~p"/api/v1/tasks/#{task.id}", %{"status" => "confirmed"})
      body = json_response(conn, 200)

      assert body["task"]["status"] == "confirmed"
      assert body["task"]["id"] == task.id
    end

    test "returns 404 when task does not exist", %{conn: conn} do
      conn = authed_conn(conn)
             |> patch(~p"/api/v1/tasks/#{Ecto.UUID.generate()}", %{"status" => "done"})
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when task belongs to different tenant", %{conn: conn} do
      task = insert(:task, tenant_id: "other-tenant")

      conn = authed_conn(conn)
             |> patch(~p"/api/v1/tasks/#{task.id}", %{"status" => "done"})
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 422 when update attributes are invalid", %{conn: conn} do
      task = insert(:task, tenant_id: @tenant)

      conn = authed_conn(conn)
             |> patch(~p"/api/v1/tasks/#{task.id}", %{"confidence" => "9999"})
      assert json_response(conn, 422)
    end

    test "can update task title", %{conn: conn} do
      task = insert(:task, tenant_id: @tenant, title: "Original")

      conn = authed_conn(conn)
             |> patch(~p"/api/v1/tasks/#{task.id}", %{"title" => "Updated"})
      assert json_response(conn, 200)["task"]["title"] == "Updated"
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/tasks/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/tasks/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      task = insert(:task, tenant_id: @tenant)
      conn = delete(conn, ~p"/api/v1/tasks/#{task.id}")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "deletes the task and returns 204", %{conn: conn} do
      task = insert(:task, tenant_id: @tenant)

      conn = authed_conn(conn) |> delete(~p"/api/v1/tasks/#{task.id}")
      assert response(conn, 204) == ""
    end

    test "returns 404 when task does not exist", %{conn: conn} do
      conn = authed_conn(conn) |> delete(~p"/api/v1/tasks/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when task belongs to different tenant", %{conn: conn} do
      task = insert(:task, tenant_id: "other-tenant")

      conn = authed_conn(conn) |> delete(~p"/api/v1/tasks/#{task.id}")
      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
