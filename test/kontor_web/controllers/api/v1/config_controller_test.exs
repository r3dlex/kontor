defmodule KontorWeb.API.V1.ConfigControllerTest do
  @moduledoc """
  Tests for ConfigController: show/2, update/2.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-config-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/config
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/config" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/config")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns config JSON for authenticated user", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/config")
      body = json_response(conn, 200)

      assert Map.has_key?(body, "config")
      config = body["config"]
      assert Map.has_key?(config, "ui_theme")
      assert Map.has_key?(config, "dark_light_mode")
      assert Map.has_key?(config, "font_size")
      assert Map.has_key?(config, "font_type")
    end

    test "returns expected default values", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/config")
      config = json_response(conn, 200)["config"]

      assert config["ui_theme"] == "system"
      assert config["dark_light_mode"] == "system"
      assert config["font_size"] == "14px"
      assert config["font_type"] == "system"
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/config
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/config" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/config", %{"ui_theme" => "dark"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns 200 with echoed config and status updated", %{conn: conn} do
      params = %{"ui_theme" => "dark", "font_size" => "16px"}

      conn = authed_conn(conn) |> put(~p"/api/v1/config", params)
      body = json_response(conn, 200)

      assert body["status"] == "updated"
      assert Map.has_key?(body, "config")
    end

    test "accepts any params as config update stub", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/config", %{"custom_key" => "custom_value"})

      body = json_response(conn, 200)
      assert body["status"] == "updated"
    end
  end
end
