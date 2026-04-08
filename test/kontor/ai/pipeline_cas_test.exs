defmodule Kontor.AI.PipelineCASTest do
  @moduledoc """
  Tests for the email reference storage behavior in the AI pipeline:
  - Sandbox key fix (Step 0)
  - CAS mark_thread_processed (Step 4)
  - Body cleanup when copy_emails=false (Step 4)
  - Body preservation when copy_emails=true (Step 4)
  """

  use Kontor.DataCase, async: false

  # Sandbox GenServer runs in a separate process; shared mode grants it DB access
  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Kontor.Repo, {:shared, self()})
    :ok
  end

  alias Kontor.Mail
  alias Kontor.Mail.{Thread, Email}
  alias Kontor.Repo

  @tenant "tenant-pipeline-cas-test"

  defp mailbox_for_tenant(copy_emails \\ false) do
    user = insert(:user, tenant_id: @tenant)
    insert(:mailbox, tenant_id: @tenant, user_id: user.id, copy_emails: copy_emails)
  end

  defp email_with_body(mailbox, thread_id) do
    insert(:email,
      tenant_id: @tenant,
      mailbox_id: mailbox.id,
      thread_id: thread_id,
      message_id: "cas-msg-#{System.unique_integer([:positive])}",
      body: "Test body content",
      received_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
  end

  # ---------------------------------------------------------------------------
  # Step 0: Sandbox key fix verification
  # ---------------------------------------------------------------------------

  describe "Sandbox :write_thread_markdown key fix" do
    test "Sandbox.execute with :content key matches the correct clause" do
      thread_id = "sandbox-fix-thread-#{System.unique_integer([:positive])}"
      result = Kontor.AI.Sandbox.execute(
        :write_thread_markdown,
        %{thread_id: thread_id, content: "# Updated markdown"},
        @tenant
      )
      assert match?({:ok, _}, result)
    end

    test "write_thread_markdown creates or updates thread markdown" do
      thread_id = "sandbox-fix-create-#{System.unique_integer([:positive])}"
      {:ok, thread} = Kontor.AI.Sandbox.execute(
        :write_thread_markdown,
        %{thread_id: thread_id, content: "# Hello"},
        @tenant
      )
      assert thread.markdown_content == "# Hello"
      assert thread.thread_id == thread_id
    end
  end

  # ---------------------------------------------------------------------------
  # Step 4: mark_thread_processed/2 — atomic CAS
  # ---------------------------------------------------------------------------

  describe "mark_thread_processed/2" do
    test "returns {:ok, :updated} when thread is stale" do
      thread_id = "cas-stale-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: @tenant, thread_id: thread_id, markdown_stale: true)

      assert {:ok, :updated} = Mail.mark_thread_processed(thread_id, @tenant)

      thread = Repo.get_by(Thread, thread_id: thread_id, tenant_id: @tenant)
      assert thread.markdown_stale == false
    end

    test "returns {:ok, :already_processed} when thread is already clean" do
      thread_id = "cas-clean-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: @tenant, thread_id: thread_id, markdown_stale: false)

      assert {:ok, :already_processed} = Mail.mark_thread_processed(thread_id, @tenant)
    end

    test "returns {:ok, :already_processed} when thread does not exist" do
      assert {:ok, :already_processed} = Mail.mark_thread_processed("nonexistent-thread", @tenant)
    end

    test "CAS is idempotent: second call after first returns :already_processed" do
      thread_id = "cas-idempotent-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: @tenant, thread_id: thread_id, markdown_stale: true)

      assert {:ok, :updated} = Mail.mark_thread_processed(thread_id, @tenant)
      assert {:ok, :already_processed} = Mail.mark_thread_processed(thread_id, @tenant)
    end

    test "does not affect threads for other tenants" do
      thread_id = "cas-tenant-#{System.unique_integer([:positive])}"
      other_tenant = "other-tenant-cas-#{System.unique_integer([:positive])}"
      insert(:thread, tenant_id: other_tenant, thread_id: thread_id, markdown_stale: true)

      # Calling for @tenant should not affect other_tenant's thread
      assert {:ok, :already_processed} = Mail.mark_thread_processed(thread_id, @tenant)

      thread = Repo.get_by(Thread, thread_id: thread_id, tenant_id: other_tenant)
      assert thread.markdown_stale == true
    end
  end

  # ---------------------------------------------------------------------------
  # Step 4: clear_email_body/1
  # ---------------------------------------------------------------------------

  describe "clear_email_body/1" do
    test "nils out body and raw_headers and sets processed_at" do
      mailbox = mailbox_for_tenant()
      email = email_with_body(mailbox, "body-clear-thread-#{System.unique_integer([:positive])}")

      assert {:ok, updated} = Mail.clear_email_body(email)
      assert updated.body == nil
      assert updated.raw_headers == nil
      assert updated.processed_at != nil
    end

    test "processed_at is set to a recent timestamp" do
      mailbox = mailbox_for_tenant()
      email = email_with_body(mailbox, "body-ts-thread-#{System.unique_integer([:positive])}")
      before = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, updated} = Mail.clear_email_body(email)

      assert DateTime.compare(updated.processed_at, before) in [:gt, :eq]
    end
  end

  # ---------------------------------------------------------------------------
  # Step 4: copy_emails schema field
  # ---------------------------------------------------------------------------

  describe "Mailbox copy_emails field" do
    test "accepts copy_emails: true in changeset" do
      user = insert(:user, tenant_id: @tenant)
      attrs = %{
        user_id: user.id,
        provider: :google,
        email_address: "copy-true-#{System.unique_integer([:positive])}@example.com",
        copy_emails: true
      }
      assert {:ok, mailbox} = Kontor.Accounts.create_mailbox(attrs, @tenant)
      assert mailbox.copy_emails == true
    end

    test "defaults copy_emails to false" do
      user = insert(:user, tenant_id: @tenant)
      attrs = %{
        user_id: user.id,
        provider: :google,
        email_address: "copy-default-#{System.unique_integer([:positive])}@example.com"
      }
      assert {:ok, mailbox} = Kontor.Accounts.create_mailbox(attrs, @tenant)
      assert mailbox.copy_emails == false
    end
  end

  # ---------------------------------------------------------------------------
  # Step 2: Thread markdown_stale field
  # ---------------------------------------------------------------------------

  describe "Thread markdown_stale field" do
    test "accepts markdown_stale: false in changeset" do
      cs = Kontor.Mail.Thread.changeset(%Thread{}, %{
        tenant_id: @tenant,
        thread_id: "cs-stale-#{System.unique_integer([:positive])}",
        markdown_stale: false
      })
      assert cs.valid?
      assert Ecto.Changeset.get_change(cs, :markdown_stale) == false
    end

    test "defaults markdown_stale to true" do
      thread = insert(:thread, tenant_id: @tenant, thread_id: "default-stale-#{System.unique_integer([:positive])}")
      # The factory does not set markdown_stale, so DB default (true) applies
      assert thread.markdown_stale == true
    end
  end

  # ---------------------------------------------------------------------------
  # Nil-id guard: Email.changeset allows nil body
  # ---------------------------------------------------------------------------

  describe "Email body nullable" do
    test "Email.changeset allows body: nil" do
      mailbox = mailbox_for_tenant()
      cs = Email.changeset(%Email{}, %{
        tenant_id: @tenant,
        mailbox_id: mailbox.id,
        message_id: "nil-body-msg-#{System.unique_integer([:positive])}",
        body: nil
      })
      assert cs.valid?
    end
  end
end
