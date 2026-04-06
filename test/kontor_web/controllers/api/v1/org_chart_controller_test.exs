defmodule KontorWeb.API.V1.OrgChartControllerTest do
  @moduledoc """
  Tests for OrgChartController: index/2, create/2, update/2.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-orgchart-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/org-charts
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/org-charts" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/org-charts")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns empty list when no org charts exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/org-charts")
      body = json_response(conn, 200)

      assert body["org_charts"] == []
    end

    test "returns org charts for the authenticated tenant", %{conn: conn} do
      Kontor.Contacts.create_org_chart(%{"name" => "Chart A"}, @tenant)
      Kontor.Contacts.create_org_chart(%{"name" => "Chart B"}, @tenant)
      Kontor.Contacts.create_org_chart(%{"name" => "Other Chart"}, "other-tenant")

      conn = authed_conn(conn) |> get(~p"/api/v1/org-charts")
      body = json_response(conn, 200)

      assert length(body["org_charts"]) == 2
    end

    test "org chart JSON includes required fields", %{conn: conn} do
      Kontor.Contacts.create_org_chart(%{"name" => "Field Check"}, @tenant)

      conn = authed_conn(conn) |> get(~p"/api/v1/org-charts")
      [chart] = json_response(conn, 200)["org_charts"]

      assert Map.has_key?(chart, "id")
      assert Map.has_key?(chart, "name")
      assert Map.has_key?(chart, "source")
      assert Map.has_key?(chart, "structure_json")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/org-charts
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/org-charts" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/org-charts", %{"name" => "New Chart"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "creates org chart with valid params and returns 201", %{conn: conn} do
      params = %{
        "name" => "Engineering Org",
        "source" => "manual",
        "structure_json" => %{"nodes" => []}
      }

      conn = authed_conn(conn) |> post(~p"/api/v1/org-charts", params)
      body = json_response(conn, 201)

      assert body["org_chart"]["name"] == "Engineering Org"
      assert Map.has_key?(body["org_chart"], "id")
    end

    test "returns 422 when name is missing", %{conn: conn} do
      conn = authed_conn(conn) |> post(~p"/api/v1/org-charts", %{})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/org-charts/:id
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/org-charts/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      {:ok, chart} = Kontor.Contacts.create_org_chart(%{"name" => "To Update"}, @tenant)
      conn = put(conn, ~p"/api/v1/org-charts/#{chart.id}", %{"name" => "Updated"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "updates org chart and returns updated JSON", %{conn: conn} do
      {:ok, chart} =
        Kontor.Contacts.create_org_chart(%{"name" => "Original Name"}, @tenant)

      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/org-charts/#{chart.id}", %{"name" => "Updated Name"})

      body = json_response(conn, 200)
      assert body["org_chart"]["name"] == "Updated Name"
      assert body["org_chart"]["id"] == chart.id
    end

    test "returns 404 when org chart does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/org-charts/#{Ecto.UUID.generate()}", %{"name" => "X"})

      assert json_response(conn, 404)["error"] == "not found"
    end

    test "returns 404 when org chart belongs to a different tenant", %{conn: conn} do
      {:ok, chart} =
        Kontor.Contacts.create_org_chart(%{"name" => "Other Chart"}, "other-tenant")

      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/org-charts/#{chart.id}", %{"name" => "X"})

      assert json_response(conn, 404)["error"] == "not found"
    end
  end
end
