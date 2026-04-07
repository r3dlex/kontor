import Config

config :kontor, Kontor.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  database: "kontor_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :kontor, KontorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4738],
  secret_key_base: "test_secret_key_base_at_least_64_bytes_long_for_security_here_kontor_app",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
config :kontor, Oban, testing: :inline

config :kontor, :google_client, Kontor.Auth.GoogleMock
config :kontor, :microsoft_client, Kontor.Auth.MicrosoftMock
config :kontor, :accounts_module, Kontor.Accounts.Mock

config :kontor, :skills_path,
  shared: System.tmp_dir!()
