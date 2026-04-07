import Config

config :kontor,
  ecto_repos: [Kontor.Repo],
  tenant_id: System.get_env("KONTOR_TENANT_ID", "default")

config :kontor, KontorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: KontorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Kontor.PubSub,
  live_view: [signing_salt: "kontor_lv_salt"]

config :kontor, Kontor.Repo,
  migration_timestamps: [type: :utc_datetime]

config :kontor, Oban,
  repo: Kontor.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"*/5 * * * *", Kontor.Mail.MarkdownBackfillWorker}
     ]}
  ],
  queues: [
    default: 5,
    mail_import: 3,
    mail_send: 1,
    ai_processing: 5,
    calendar_sync: 2,
    contact_sync: 2,
    asana_sync: 1,
    markdown_backfill: 2
  ]

config :kontor, :mcp,
  require_mcp_auth: false

config :kontor, Kontor.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!(System.get_env("CLOAK_KEY", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")),
      iv_length: 12
    }
  ]

config :kontor, :minimax,
  api_key: System.get_env("MINIMAX_API_KEY"),
  base_url: "https://api.minimax.chat/v1",
  model: "abab6.5s-chat",
  max_tokens: 4096,
  cache_ttl_seconds: 3600

config :kontor, :embeddings,
  model: {:hf, "sentence-transformers/all-MiniLM-L6-v2"},
  dimensions: 384

config :kontor, :skills_path,
  shared: "priv/skills/shared",
  profiles: "priv/profiles"

config :kontor, :mail,
  default_polling_interval_seconds: 60,
  default_task_age_cutoff_months: 3,
  import_throttle_emails_per_second: 5

config :kontor, :tasks,
  auto_confirm_threshold_high: 0.85,
  auto_confirm_threshold_low: 0.5

config :kontor, :n8n,
  enabled: false,
  base_url: System.get_env("N8N_BASE_URL", "http://localhost:5678")

import_config "#{config_env()}.exs"
