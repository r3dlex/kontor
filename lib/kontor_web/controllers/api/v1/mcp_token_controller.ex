defmodule KontorWeb.API.V1.McpTokenController do
  use KontorWeb, :controller

  def create(conn, _params) do
    tenant_id = conn.assigns[:tenant_id] || Kontor.tenant_id()

    claims = %{
      "tenant_id" => tenant_id,
      "mcp" => true,
      "exp" => System.system_time(:second) + 3600
    }

    {:ok, json} = Jason.encode(claims)
    token = Base.url_encode64(json, padding: false)

    json(conn, %{token: token, expires_in: 3600})
  end
end
