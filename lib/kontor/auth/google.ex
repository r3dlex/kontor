defmodule Kontor.Auth.Google do
  @moduledoc "Google OAuth 2.0 client for token exchange and refresh."
  require Logger

  @token_url "https://oauth2.googleapis.com/token"

  # 1-arg convenience: uses redirect_uri from config
  def exchange_code(code) do
    redirect_uri = Application.get_env(:kontor, :google_oauth, [])[:redirect_uri] ||
      "http://localhost:4000/api/v1/auth/google"
    exchange_code(code, redirect_uri)
  end

  def get_profile(access_token), do: get_user_info(access_token)

  def exchange_code(code, redirect_uri) do
    config = Application.get_env(:kontor, :google_oauth)

    body = %{
      code: code,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: redirect_uri,
      grant_type: "authorization_code"
    }

    case Req.post(@token_url, form: body) do
      {:ok, %{status: 200, body: token_data}} -> {:ok, token_data}
      {:ok, %{body: err}} -> {:error, err}
      {:error, reason} -> {:error, reason}
    end
  end

  def refresh_token(%{refresh_token_encrypted: encrypted, tenant_id: tenant_id, user_id: user_id}) do
    config = Application.get_env(:kontor, :google_oauth)
    refresh_token = Kontor.Vault.decrypt!(encrypted)

    body = %{
      refresh_token: refresh_token,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      grant_type: "refresh_token"
    }

    case Req.post(@token_url, form: body) do
      {:ok, %{status: 200, body: %{"access_token" => access_token, "expires_in" => expires_in}}} ->
        expires_at = DateTime.add(DateTime.utc_now(), expires_in) |> DateTime.truncate(:second)

        Kontor.Accounts.upsert_credential(%{
          tenant_id: tenant_id,
          user_id: user_id,
          provider: "google",
          access_token_encrypted: Kontor.Vault.encrypt!(access_token),
          refresh_token_encrypted: encrypted,
          expires_at: expires_at
        })

      {:ok, %{body: err}} -> {:error, err}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_user_info(access_token) do
    case Req.get("https://www.googleapis.com/oauth2/v2/userinfo",
           headers: [{"Authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 200, body: info}} -> {:ok, info}
      {:error, reason} -> {:error, reason}
    end
  end
end
