defmodule KontorWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :kontor

  @session_options [
    store: :cookie,
    key: "_kontor_key",
    signing_salt: "kontor_salt",
    same_site: "Lax"
  ]

  socket "/socket", KontorWeb.UserSocket,
    websocket: true,
    longpoll: false

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug KontorWeb.Router
end
