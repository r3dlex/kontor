defmodule KontorWeb.Auth do
  @moduledoc "JWT-like token generation and verification for v1 single-tenant."

  def generate_token(user_id, tenant_id) do
    claims = %{
      "sub" => user_id,
      "tenant_id" => tenant_id,
      "exp" => System.system_time(:second) + 86_400
    }

    {:ok, Jason.encode!(claims) |> Base.url_encode64(padding: false)}
  end

  def verify_token(token) do
    with {:ok, json} <- Base.url_decode64(token, padding: false),
         {:ok, claims} <- Jason.decode(json),
         exp when is_integer(exp) <- claims["exp"],
         true <- exp > System.system_time(:second) do
      {:ok, claims}
    else
      _ -> {:error, :invalid_token}
    end
  end
end
