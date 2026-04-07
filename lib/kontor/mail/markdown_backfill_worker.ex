defmodule Kontor.Mail.MarkdownBackfillWorker do
  @moduledoc """
  Oban worker that batch-processes stale threads from the Importer path.

  The Importer does not call Pipeline.process_email/1 directly (to keep
  bulk-import simple). Instead, this worker runs on a 5-minute cron and
  finds threads with markdown_stale = true, then feeds the most recent
  email with a non-nil body into the pipeline.

  Body-nil guard: if no email with a body is found for a stale thread
  (all bodies already cleaned or thread has no emails), the thread is
  marked clean and a warning is logged to prevent an infinite retry loop.
  """

  use Oban.Worker, queue: :markdown_backfill, max_attempts: 3

  import Ecto.Query

  require Logger

  alias Kontor.{Repo, Mail}
  alias Kontor.Mail.Email
  alias Kontor.Accounts.Mailbox

  @batch_size 50

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    tenant_ids = Kontor.Accounts.list_tenant_ids()

    Enum.each(tenant_ids, fn tenant_id ->
      stale = Mail.stale_threads(tenant_id, limit: @batch_size)

      Enum.each(stale, fn thread ->
        process_stale_thread(thread, tenant_id)
      end)
    end)

    :ok
  end

  defp process_stale_thread(thread, tenant_id) do
    email =
      Repo.one(
        from e in Email,
        where:
          e.thread_id == ^thread.thread_id and
          e.tenant_id == ^tenant_id and
          not is_nil(e.body),
        order_by: [desc: e.received_at],
        limit: 1
      )

    case email do
      nil ->
        # Body-nil guard: no email with body found — mark clean to stop retry loop
        Logger.warning(
          "MarkdownBackfillWorker: thread #{thread.thread_id} (tenant #{tenant_id}) " <>
          "marked stale but no email body available — marking clean to prevent retry loop."
        )
        Mail.mark_thread_processed(thread.thread_id, tenant_id)

      email ->
        mailbox = Repo.get(Mailbox, email.mailbox_id)
        cutoff = (mailbox && mailbox.task_age_cutoff_months) || 3
        Kontor.AI.Pipeline.process_email(email, task_age_cutoff_months: cutoff)
    end
  end
end
