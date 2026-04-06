defmodule Kontor.Auth.Microsoft do
  @moduledoc "Microsoft OAuth 2.0 client via DavMail proxy."
  require Logger

  @token_url "https://login.microsoftonline.com/common/oauth2/v2.0/token"

  # 1-arg convenience: uses redirect_uri from config
  def exchange_code(code) do
    redirect_uri = Application.get_env(:kontor, :microsoft_oauth, [])[:redirect_uri] ||
      "http://localhost:4000/api/v1/auth/microsoft"
    exchange_code(code, redirect_uri)
  end

  def get_profile(access_token), do: get_user_info(access_token)

  def exchange_code(code, redirect_uri) do
    config = Application.get_env(:kontor, :microsoft_oauth)

    body = %{
      code: code,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: redirect_uri,
      grant_type: "authorization_code",
      scope: "https://graph.microsoft.com/.default offline_access"
    }

    case Req.post(@token_url, form: body) do
      {:ok, %{status: 200, body: token_data}} -> {:ok, token_data}
      {:ok, %{body: err}} -> {:error, err}
      {:error, reason} -> {:error, reason}
    end
  end

  def refresh_token(%{refresh_token_encrypted: encrypted, tenant_id: tenant_id, user_id: user_id}) do
    config = Application.get_env(:kontor, :microsoft_oauth)
    refresh_token = Kontor.Vault.decrypt!(encrypted)

    body = %{
      refresh_token: refresh_token,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      grant_type: "refresh_token",
      scope: "https://graph.microsoft.com/.default offline_access"
    }

    case Req.post(@token_url, form: body) do
      {:ok, %{status: 200, body: %{"access_token" => access_token, "refresh_token" => new_refresh, "expires_in" => expires_in}}} ->
        expires_at = DateTime.add(DateTime.utc_now(), expires_in) |> DateTime.truncate(:second)

        Kontor.Accounts.upsert_credential(%{
          tenant_id: tenant_id,
          user_id: user_id,
          provider: "microsoft",
          access_token_encrypted: Kontor.Vault.encrypt!(access_token),
          refresh_token_encrypted: Kontor.Vault.encrypt!(new_refresh),
          expires_at: expires_at
        })

      {:ok, %{body: err}} -> {:error, err}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_user_info(access_token) do
    case Req.get("https://graph.microsoft.com/v1.0/me",
           headers: [{"Authorization", "Bearer #{access_token}"}]) do
      {:ok, %{status: 200, body: info}} -> {:ok, info}
      {:error, reason} -> {:error, reason}
    end
  end
end
