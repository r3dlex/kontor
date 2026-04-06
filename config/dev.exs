import Config

config :kontor, Kontor.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "kontor_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :kontor, KontorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_at_least_64_bytes_long_for_security_here_kontor_app",
  watchers: []

config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
