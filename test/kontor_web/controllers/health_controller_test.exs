defmodule KontorWeb.HealthControllerTest do
  use KontorWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns status ok and version", %{conn: conn} do
      conn = get(conn, ~p"/health")
      body = json_response(conn, 200)

      assert body["status"] == "ok"
      assert body["version"] == "0.1.0"
    end

    test "does not require authentication", %{conn: conn} do
      conn = get(conn, ~p"/health")
      assert json_response(conn, 200)
    end
  end
end
