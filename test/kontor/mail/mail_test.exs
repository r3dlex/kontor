defmodule Kontor.MailTest do
  use Kontor.DataCase, async: true

  alias Kontor.Mail

  @tenant "tenant-mail-test"

  # Helper: insert a mailbox scoped to @tenant
  defp mailbox_for_tenant(tenant \\ @tenant) do
    user = insert(:user, tenant_id: tenant)
    insert(:mailbox, tenant_id: tenant, user_id: user.id)
  end

  # Helper: insert an email scoped to @tenant
  defp email_in_tenant(attrs \\ []) do
    mailbox = mailbox_for_tenant()
    base = [tenant_id: @tenant, mailbox_id: mailbox.id]
    insert(:email, Keyword.merge(base, attrs))
  end

  # ---------------------------------------------------------------------------
  # get_email/2
  # ---------------------------------------------------------------------------

  describe "get_email/2" do
    test "returns {:ok, email} when email is found for tenant" do
      email = email_in_tenant()

      assert {:ok, found} = Mail.get_email(email.id, @tenant)
      assert found.id == email.id
    end

    test "returns {:error, :not_found} when email id does not exist" do
      assert {:error, :not_found} = Mail.get_email(Ecto.UUID.generate(), @tenant)
    end

    test "returns {:error, :not_found} when email belongs to different tenant" do
      other_mb = mailbox_for_tenant("other-tenant")
      email = insert(:email, tenant_id: "other-tenant", mailbox_id: other_mb.id,
                     message_id: "other-msg-1")

      assert {:error, :not_found} = Mail.get_email(email.id, @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # list_thread_emails/3
  # ---------------------------------------------------------------------------

  describe "list_thread_emails/3" do
    test "returns emails for given thread and tenant ordered by received_at asc" do
      mailbox = mailbox_for_tenant()
      t_id = "thread-abc-123"
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      e1 = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
                  thread_id: t_id, message_id: "sort-msg-1",
                  received_at: DateTime.add(now, -120))
      e2 = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
                  thread_id: t_id, message_id: "sort-msg-2",
                  received_at: DateTime.add(now, -60))
      e3 = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
                  thread_id: t_id, message_id: "sort-msg-3",
                  received_at: now)

      results = Mail.list_thread_emails(t_id, @tenant)

      assert length(results) == 3
      assert Enum.map(results, & &1.id) == [e1.id, e2.id, e3.id]
    end

    test "returns empty list when thread has no emails" do
      assert Mail.list_thread_emails("nonexistent-thread", @tenant) == []
    end

    test "does not return emails from a different thread" do
      mailbox = mailbox_for_tenant()
      insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
             thread_id: "thread-A", message_id: "diff-thread-msg-1")

      assert Mail.list_thread_emails("thread-B", @tenant) == []
    end

    test "does not return emails from different tenant" do
      other_mb = mailbox_for_tenant("other-tenant")
      insert(:email, tenant_id: "other-tenant", mailbox_id: other_mb.id,
             thread_id: "thread-X", message_id: "other-tenant-msg-1")

      assert Mail.list_thread_emails("thread-X", @tenant) == []
    end

    test "respects limit option" do
      mailbox = mailbox_for_tenant()
      t_id = "thread-limit-test"
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..5, fn i ->
        insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
               thread_id: t_id, message_id: "limit-msg-#{i}",
               received_at: DateTime.add(now, i))
      end)

      results = Mail.list_thread_emails(t_id, @tenant, limit: 2)
      assert length(results) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # update_thread_markdown/3
  # ---------------------------------------------------------------------------

  describe "update_thread_markdown/3" do
    test "inserts a new thread record when none exists" do
      thread_id = "new-thread-md-#{System.unique_integer([:positive])}"
      content = "# Summary\n\nNew content"

      assert {:ok, thread} = Mail.update_thread_markdown(thread_id, content, @tenant)
      assert thread.thread_id == thread_id
      assert thread.markdown_content == content
      assert thread.tenant_id == @tenant
    end

    test "updates existing thread markdown content" do
      thread_id = "existing-thread-md-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: @tenant, thread_id: thread_id,
             markdown_content: "Old content")

      assert {:ok, updated} = Mail.update_thread_markdown(thread_id, "Updated content", @tenant)
      assert updated.markdown_content == "Updated content"
    end

    test "does not affect threads for other tenants with same thread_id" do
      thread_id = "shared-thread-id-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: "other-tenant", thread_id: thread_id,
             markdown_content: "Other content")

      assert {:ok, thread} = Mail.update_thread_markdown(thread_id, "My content", @tenant)
      assert thread.tenant_id == @tenant
      assert thread.markdown_content == "My content"
    end

    test "updates last_updated timestamp on insert" do
      before = DateTime.utc_now() |> DateTime.truncate(:second)
      thread_id = "ts-thread-#{System.unique_integer([:positive])}"

      {:ok, thread} = Mail.update_thread_markdown(thread_id, "Content", @tenant)

      assert DateTime.compare(thread.last_updated, before) in [:gt, :eq]
    end

    test "updates last_updated timestamp on update" do
      thread_id = "ts-update-thread-#{System.unique_integer([:positive])}"
      old_time = DateTime.add(DateTime.utc_now(), -3600) |> DateTime.truncate(:second)
      insert(:thread, tenant_id: @tenant, thread_id: thread_id, last_updated: old_time)

      {:ok, updated} = Mail.update_thread_markdown(thread_id, "New content", @tenant)

      assert DateTime.compare(updated.last_updated, old_time) == :gt
    end
  end

  # ---------------------------------------------------------------------------
  # update_thread_scores/3
  # ---------------------------------------------------------------------------

  describe "update_thread_scores/3" do
    test "updates all score fields when thread exists" do
      thread_id = "score-thread-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: @tenant, thread_id: thread_id)

      scores = %{
        thread_id: thread_id,
        score_urgency: 0.8,
        score_action: 0.7,
        score_authority: 0.6,
        score_momentum: 0.5
      }

      assert {:ok, updated} = Mail.update_thread_scores(thread_id, scores, @tenant)
      assert updated.score_urgency == 0.8
      assert updated.score_action == 0.7
      assert updated.score_authority == 0.6
      assert updated.score_momentum == 0.5
    end

    test "calculates composite_score as average of the four score fields" do
      thread_id = "composite-thread-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: @tenant, thread_id: thread_id)

      scores = %{
        thread_id: thread_id,
        score_urgency: 1.0,
        score_action: 0.5,
        score_authority: 0.5,
        score_momentum: 0.0
      }

      assert {:ok, updated} = Mail.update_thread_scores(thread_id, scores, @tenant)
      assert_in_delta updated.composite_score, 0.5, 0.001
    end

    test "returns {:error, :not_found} when thread does not exist" do
      scores = %{
        thread_id: "nonexistent",
        score_urgency: 0.5,
        score_action: 0.5,
        score_authority: 0.5,
        score_momentum: 0.5
      }

      assert {:error, :not_found} = Mail.update_thread_scores("nonexistent", scores, @tenant)
    end

    test "returns {:error, :not_found} when thread belongs to different tenant" do
      thread_id = "other-score-thread-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: "other-tenant", thread_id: thread_id)

      scores = %{thread_id: thread_id, score_urgency: 0.5, score_action: 0.5,
                 score_authority: 0.5, score_momentum: 0.5}

      assert {:error, :not_found} = Mail.update_thread_scores(thread_id, scores, @tenant)
    end
  end
end
