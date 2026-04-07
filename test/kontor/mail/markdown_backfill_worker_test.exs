defmodule Kontor.Mail.MarkdownBackfillWorkerTest do
  use Kontor.DataCase, async: false

  alias Kontor.Mail
  alias Kontor.Mail.{Thread, Email, MarkdownBackfillWorker}
  alias Kontor.Repo

  @tenant "tenant-backfill-worker-test"

  defp mailbox_for_tenant do
    user = insert(:user, tenant_id: @tenant)
    insert(:mailbox, tenant_id: @tenant, user_id: user.id)
  end

  # ---------------------------------------------------------------------------
  # perform/1
  # ---------------------------------------------------------------------------

  describe "perform/1 — empty stale set" do
    test "returns :ok with no stale threads" do
      # Ensure no stale threads exist for this tenant by inserting a clean one
      insert(:thread, tenant_id: @tenant, thread_id: "clean-#{System.unique_integer([:positive])}", markdown_stale: false)

      job = %Oban.Job{args: %{}}
      assert :ok = MarkdownBackfillWorker.perform(job)
    end
  end

  describe "perform/1 — body-nil guard" do
    test "marks thread clean and logs warning when no email body is found" do
      # Ensure tenant appears in list_tenant_ids/0
      insert(:user, tenant_id: @tenant)
      thread_id = "no-body-thread-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: @tenant, thread_id: thread_id, markdown_stale: true)

      # Insert email with nil body for this thread
      mailbox = mailbox_for_tenant()
      insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
             thread_id: thread_id, message_id: "no-body-msg-#{System.unique_integer([:positive])}",
             body: nil)

      job = %Oban.Job{args: %{}}
      assert :ok = MarkdownBackfillWorker.perform(job)

      # Thread should be marked clean (body-nil guard)
      thread = Repo.get_by(Thread, thread_id: thread_id, tenant_id: @tenant)
      assert thread.markdown_stale == false
    end

    test "marks thread clean when thread has no emails at all" do
      # Insert a user so list_tenant_ids/0 returns this tenant
      insert(:user, tenant_id: @tenant)
      thread_id = "empty-thread-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: @tenant, thread_id: thread_id, markdown_stale: true)

      job = %Oban.Job{args: %{}}
      assert :ok = MarkdownBackfillWorker.perform(job)

      thread = Repo.get_by(Thread, thread_id: thread_id, tenant_id: @tenant)
      assert thread.markdown_stale == false
    end
  end

  describe "perform/1 — stale_threads query" do
    test "stale_threads/2 returns only stale threads for tenant" do
      stale_id = "stale-q-#{System.unique_integer([:positive])}"
      clean_id = "clean-q-#{System.unique_integer([:positive])}"

      insert(:thread, tenant_id: @tenant, thread_id: stale_id, markdown_stale: true)
      insert(:thread, tenant_id: @tenant, thread_id: clean_id, markdown_stale: false)

      stale = Mail.stale_threads(@tenant)
      stale_thread_ids = Enum.map(stale, & &1.thread_id)

      assert stale_id in stale_thread_ids
      refute clean_id in stale_thread_ids
    end

    test "stale_threads/2 does not return stale threads from other tenants" do
      other_tenant = "other-tenant-backfill-#{System.unique_integer([:positive])}"
      other_thread_id = "other-stale-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: other_tenant, thread_id: other_thread_id, markdown_stale: true)

      stale = Mail.stale_threads(@tenant)
      stale_thread_ids = Enum.map(stale, & &1.thread_id)
      refute other_thread_id in stale_thread_ids
    end

    test "stale_threads/2 respects limit" do
      Enum.each(1..5, fn i ->
        insert(:thread, tenant_id: @tenant,
               thread_id: "limit-stale-#{System.unique_integer([:positive])}-#{i}",
               markdown_stale: true)
      end)

      result = Mail.stale_threads(@tenant, limit: 2)
      assert length(result) <= 2
    end
  end
end
