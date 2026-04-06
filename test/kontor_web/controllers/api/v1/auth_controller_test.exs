defmodule KontorWeb.API.V1.AuthControllerTest do
  use KontorWeb.ConnCase, async: false

  import Mox

  # ---------------------------------------------------------------------------
  # The auth controller calls these functions directly on the module:
  #
  #   Kontor.Auth.Google.exchange_code(code)           — 1-arg
  #   Kontor.Auth.Google.get_profile(access_token)     — 1-arg
  #   Accounts.upsert_user_from_google(profile, tokens)
  #
  #   Kontor.Auth.Microsoft.exchange_code(code)        — 1-arg
  #   Kontor.Auth.Microsoft.get_profile(access_token)  — 1-arg
  #   Accounts.upsert_user_from_microsoft(profile, tokens)
  #
  # To intercept these calls in tests, the application must be configured to
  # resolve these modules through the application environment. The mocks below
  # use Mox with the behaviour definitions in test/support/mocks.ex.
  #
  # In test config (config/test.exs), add:
  #   config :kontor, :google_client, Kontor.Auth.GoogleMock
  #   config :kontor, :microsoft_client, Kontor.Auth.MicrosoftMock
  #   config :kontor, :accounts_module, Kontor.Accounts.Mock
  #
  # If the controller is calling the concrete modules directly (not via
  # application env), these tests document the contract and will require the
  # controller to be updated to support dependency injection.
  # ---------------------------------------------------------------------------

  setup :verify_on_exit!

  @google_tokens %{"access_token" => "g-access", "refresh_token" => "g-refresh"}
  @google_profile %{"email" => "alice@example.com", "name" => "Alice Smith", "sub" => "g-sub-123"}

  @ms_tokens %{"access_token" => "ms-access", "refresh_token" => "ms-refresh"}
  @ms_profile %{"email" => "bob@example.com", "name" => "Bob Jones", "sub" => "ms-sub-456"}

  # ---------------------------------------------------------------------------
  # POST /api/v1/auth/google
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/auth/google — success" do
    test "returns 200 with token and user when all steps succeed", %{conn: conn} do
      user = insert(:user, email: "alice@example.com", tenant_id: "tenant-alice")

      Kontor.Auth.GoogleMock
      |> expect(:exchange_code, fn "valid-code" -> {:ok, @google_tokens} end)
      |> expect(:get_profile, fn "g-access" -> {:ok, @google_profile} end)

      Kontor.Accounts.Mock
      |> expect(:upsert_user_from_google, fn _profile, _tokens -> {:ok, user} end)

      conn = post(conn, ~p"/api/v1/auth/google", %{"code" => "valid-code"})
      body = json_response(conn, 200)

      assert is_binary(body["token"])
      assert body["user"]["email"] == "alice@example.com"
      assert body["user"]["id"] == user.id
      assert body["user"]["name"] == user.name
    end
  end

  describe "POST /api/v1/auth/google — failure paths" do
    test "returns 400 when exchange_code fails", %{conn: conn} do
      Kontor.Auth.GoogleMock
      |> expect(:exchange_code, fn _code -> {:error, :invalid_code} end)

      conn = post(conn, ~p"/api/v1/auth/google", %{"code" => "bad-code"})
      body = json_response(conn, 400)

      assert body["error"] =~ "invalid_code"
    end

    test "returns 400 when get_profile fails after exchange", %{conn: conn} do
      Kontor.Auth.GoogleMock
      |> expect(:exchange_code, fn _code -> {:ok, @google_tokens} end)
      |> expect(:get_profile, fn _token -> {:error, :profile_fetch_failed} end)

      conn = post(conn, ~p"/api/v1/auth/google", %{"code" => "any-code"})
      body = json_response(conn, 400)

      assert body["error"] != nil
    end

    test "returns 400 when upsert_user_from_google fails", %{conn: conn} do
      Kontor.Auth.GoogleMock
      |> expect(:exchange_code, fn _code -> {:ok, @google_tokens} end)
      |> expect(:get_profile, fn _token -> {:ok, @google_profile} end)

      Kontor.Accounts.Mock
      |> expect(:upsert_user_from_google, fn _profile, _tokens ->
        {:error, :database_error}
      end)

      conn = post(conn, ~p"/api/v1/auth/google", %{"code" => "any-code"})
      assert json_response(conn, 400)["error"] != nil
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/auth/microsoft
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/auth/microsoft — success" do
    test "returns 200 with token and user when all steps succeed", %{conn: conn} do
      user = insert(:user, email: "bob@example.com", tenant_id: "tenant-bob")

      Kontor.Auth.MicrosoftMock
      |> expect(:exchange_code, fn "valid-ms-code" -> {:ok, @ms_tokens} end)
      |> expect(:get_profile, fn "ms-access" -> {:ok, @ms_profile} end)

      Kontor.Accounts.Mock
      |> expect(:upsert_user_from_microsoft, fn _profile, _tokens -> {:ok, user} end)

      conn = post(conn, ~p"/api/v1/auth/microsoft", %{"code" => "valid-ms-code"})
      body = json_response(conn, 200)

      assert is_binary(body["token"])
      assert body["user"]["email"] == "bob@example.com"
      assert body["user"]["id"] == user.id
    end
  end

  describe "POST /api/v1/auth/microsoft — failure paths" do
    test "returns 400 when exchange_code fails", %{conn: conn} do
      Kontor.Auth.MicrosoftMock
      |> expect(:exchange_code, fn _code -> {:error, :invalid_grant} end)

      conn = post(conn, ~p"/api/v1/auth/microsoft", %{"code" => "bad-ms-code"})
      body = json_response(conn, 400)

      assert body["error"] != nil
    end

    test "returns 400 when get_profile fails after exchange", %{conn: conn} do
      Kontor.Auth.MicrosoftMock
      |> expect(:exchange_code, fn _code -> {:ok, @ms_tokens} end)
      |> expect(:get_profile, fn _token -> {:error, :graph_api_error} end)

      conn = post(conn, ~p"/api/v1/auth/microsoft", %{"code" => "any-ms-code"})
      assert json_response(conn, 400)["error"] != nil
    end

    test "returns 400 when upsert_user_from_microsoft fails", %{conn: conn} do
      Kontor.Auth.MicrosoftMock
      |> expect(:exchange_code, fn _code -> {:ok, @ms_tokens} end)
      |> expect(:get_profile, fn _token -> {:ok, @ms_profile} end)

      Kontor.Accounts.Mock
      |> expect(:upsert_user_from_microsoft, fn _profile, _tokens ->
        {:error, :conflict}
      end)

      conn = post(conn, ~p"/api/v1/auth/microsoft", %{"code" => "any-code"})
      assert json_response(conn, 400)["error"] != nil
    end
  end
end
