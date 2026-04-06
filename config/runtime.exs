import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL environment variable is missing"

  config :kontor, Kontor.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE environment variable is missing"

  config :kontor, KontorWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
    secret_key_base: secret_key_base

  cloak_key =
    System.get_env("CLOAK_KEY") ||
      raise "CLOAK_KEY environment variable is missing"

  config :kontor, Kontor.Vault,
    ciphers: [
      default: {
        Cloak.Ciphers.AES.GCM,
        tag: "AES.GCM.V1",
        key: Base.decode64!(cloak_key),
        iv_length: 12
      }
    ]

  config :kontor, :minimax,
    api_key: System.get_env("MINIMAX_API_KEY"),
    base_url: System.get_env("MINIMAX_BASE_URL", "https://api.minimax.chat/v1"),
    model: System.get_env("MINIMAX_MODEL", "abab6.5s-chat"),
    max_tokens: 4096,
    cache_ttl_seconds: String.to_integer(System.get_env("MINIMAX_CACHE_TTL", "3600"))

  config :kontor,
    tenant_id: System.get_env("KONTOR_TENANT_ID", "default")
end
