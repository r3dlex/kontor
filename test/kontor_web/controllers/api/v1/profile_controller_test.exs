defmodule KontorWeb.API.V1.ProfileControllerTest do
  @moduledoc """
  Tests for ProfileController: index/2, create/2, update/2.
  """
  use KontorWeb.ConnCase, async: true

  @tenant "tenant-profile-ctrl"

  defp authed_conn(conn) do
    user = insert(:user, tenant_id: @tenant)
    authenticated_conn(conn, user.id, @tenant)
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/profiles
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/profiles" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/profiles")
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "returns empty list when no profiles exist", %{conn: conn} do
      conn = authed_conn(conn) |> get(~p"/api/v1/profiles")
      body = json_response(conn, 200)

      assert body["profiles"] == []
    end

    test "returns profiles for the authenticated tenant", %{conn: conn} do
      Kontor.AI.Skills.create_style_profile(
        %{"name" => "Profile A", "content" => "content a"},
        @tenant
      )

      Kontor.AI.Skills.create_style_profile(
        %{"name" => "Profile B", "content" => "content b"},
        @tenant
      )

      conn = authed_conn(conn) |> get(~p"/api/v1/profiles")
      body = json_response(conn, 200)

      assert length(body["profiles"]) == 2
    end

    test "profile JSON includes required fields", %{conn: conn} do
      Kontor.AI.Skills.create_style_profile(
        %{"name" => "Field Check", "content" => "some content"},
        @tenant
      )

      conn = authed_conn(conn) |> get(~p"/api/v1/profiles")
      [profile] = json_response(conn, 200)["profiles"]

      assert Map.has_key?(profile, "id")
      assert Map.has_key?(profile, "name")
      assert Map.has_key?(profile, "preserve_voice")
      assert Map.has_key?(profile, "auto_select_rules")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/profiles
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/profiles" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/profiles", %{"name" => "P1", "content" => "c"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "creates profile with valid params and returns 201", %{conn: conn} do
      params = %{"name" => "New Profile", "content" => "# My Style\nBe concise."}

      conn = authed_conn(conn) |> post(~p"/api/v1/profiles", params)
      body = json_response(conn, 201)

      assert body["profile"]["name"] == "New Profile"
      assert Map.has_key?(body["profile"], "id")
    end

    test "returns 422 when name is missing", %{conn: conn} do
      conn = authed_conn(conn) |> post(~p"/api/v1/profiles", %{"content" => "something"})
      assert json_response(conn, 422)
    end

    test "returns 422 when content is missing", %{conn: conn} do
      conn = authed_conn(conn) |> post(~p"/api/v1/profiles", %{"name" => "P"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/profiles/:id
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/profiles/:id" do
    test "returns 401 when no authorization header present", %{conn: conn} do
      {:ok, profile} =
        Kontor.AI.Skills.create_style_profile(
          %{"name" => "To Update", "content" => "c"},
          @tenant
        )

      conn = put(conn, ~p"/api/v1/profiles/#{profile.id}", %{"name" => "Updated"})
      assert json_response(conn, 401)["error"] == "unauthorized"
    end

    test "updates profile and returns updated JSON", %{conn: conn} do
      {:ok, profile} =
        Kontor.AI.Skills.create_style_profile(
          %{"name" => "Original Name", "content" => "original content"},
          @tenant
        )

      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/profiles/#{profile.id}", %{
          "name" => "Updated Name",
          "content" => "updated content"
        })

      body = json_response(conn, 200)
      assert body["profile"]["name"] == "Updated Name"
    end

    test "returns 422 when profile does not exist", %{conn: conn} do
      conn =
        authed_conn(conn)
        |> put(~p"/api/v1/profiles/#{Ecto.UUID.generate()}", %{"name" => "X", "content" => "y"})

      # update_style_profile returns {:error, :not_found} which maps to 422 in the controller
      assert json_response(conn, 422)
    end
  end
end
