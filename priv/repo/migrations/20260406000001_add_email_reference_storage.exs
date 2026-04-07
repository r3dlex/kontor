defmodule Kontor.Repo.Migrations.AddEmailReferenceStorage do
  use Ecto.Migration

  def up do
    # Add copy_emails flag to mailboxes (default false = reference-only mode)
    alter table(:mailboxes) do
      add :copy_emails, :boolean, null: false, default: false
    end

    # Add markdown_stale flag to threads (default true = needs processing)
    alter table(:threads) do
      add :markdown_stale, :boolean, null: false, default: true
    end

    # Make body and raw_headers nullable on emails (body nilled after pipeline success)
    alter table(:emails) do
      modify :body, :text, null: true
      modify :raw_headers, :map, null: true, default: nil
    end

    # Partial index for fast stale-thread queries in MarkdownBackfillWorker
    execute(
      "CREATE INDEX threads_stale_idx ON threads (tenant_id) WHERE markdown_stale = true",
      "DROP INDEX IF EXISTS threads_stale_idx"
    )
  end

  def down do
    execute("DROP INDEX IF EXISTS threads_stale_idx", "")

    alter table(:emails) do
      modify :body, :text, null: true
      modify :raw_headers, :map, null: true
    end

    alter table(:threads) do
      remove :markdown_stale
    end

    alter table(:mailboxes) do
      remove :copy_emails
    end
  end
end
