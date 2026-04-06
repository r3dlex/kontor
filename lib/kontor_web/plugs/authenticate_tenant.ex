defmodule KontorWeb.Plugs.AuthenticateTenant do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- KontorWeb.Auth.verify_token(token) do
      conn
      |> assign(:current_user_id, claims["sub"])
      |> assign(:tenant_id, claims["tenant_id"] || Kontor.tenant_id())
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})
        |> halt()
    end
  end
end
