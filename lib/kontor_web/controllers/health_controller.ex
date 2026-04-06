defmodule KontorWeb.HealthController do
  use KontorWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok", version: "0.1.0"})
  end
end
