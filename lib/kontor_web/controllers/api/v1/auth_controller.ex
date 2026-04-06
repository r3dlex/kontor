defmodule KontorWeb.API.V1.AuthController do
  use KontorWeb, :controller

  defp google_client, do: Application.get_env(:kontor, :google_client, Kontor.Auth.Google)
  defp microsoft_client, do: Application.get_env(:kontor, :microsoft_client, Kontor.Auth.Microsoft)
  defp accounts_module, do: Application.get_env(:kontor, :accounts_module, Kontor.Accounts)

  defp access_token(tokens) when is_map(tokens) do
    Map.get(tokens, "access_token") || Map.get(tokens, :access_token)
  end

  def google(conn, %{"code" => code}) do
    with {:ok, tokens} <- google_client().exchange_code(code),
         {:ok, profile} <- google_client().get_profile(access_token(tokens)),
         {:ok, user} <- accounts_module().upsert_user_from_google(profile, tokens) do
      {:ok, jwt} = KontorWeb.Auth.generate_token(user.id, user.tenant_id)
      json(conn, %{token: jwt, user: %{id: user.id, email: user.email, name: user.name}})
    else
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: inspect(reason)})
    end
  end

  def microsoft(conn, %{"code" => code}) do
    with {:ok, tokens} <- microsoft_client().exchange_code(code),
         {:ok, profile} <- microsoft_client().get_profile(access_token(tokens)),
         {:ok, user} <- accounts_module().upsert_user_from_microsoft(profile, tokens) do
      {:ok, jwt} = KontorWeb.Auth.generate_token(user.id, user.tenant_id)
      json(conn, %{token: jwt, user: %{id: user.id, email: user.email, name: user.name}})
    else
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: inspect(reason)})
    end
  end
end
