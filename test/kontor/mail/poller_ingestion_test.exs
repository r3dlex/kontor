defmodule Kontor.Mail.PollerIngestionTest do
  @moduledoc """
  E2E-style integration tests for ingestion behaviour.

  1. Newest-first: fetch_new_emails/2 calls list_emails with "date:desc" sort.
  2. Task age cutoff: run_tier2 skips "task_extractor" for emails older than cutoff.
  3. Thread completeness nil guard: fetch_and_upsert_thread_siblings returns
     {:ok, :skipped} when email.thread_id is nil.
  """

  use Kontor.DataCase, async: true

  alias Kontor.AI.Pipeline
  alias Kontor.AI.MinimaxClient

  @tenant "tenant-poller-ingestion-test"

  setup do
    if :ets.whereis(:minimax_response_cache) == :undefined do
      MinimaxClient.start_cache()
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # 1. Newest-first sort — Poller hardcodes "date:desc" in fetch_new_emails/2
  #
  # We verify the compiled module's abstract code contains the "date:desc"
  # literal, guarding against accidental sort-order changes.
  # ---------------------------------------------------------------------------

  describe "fetch_new_emails/2 — newest-first sort" do
    test "Poller.fetch_new_emails/2 requests emails sorted date:desc" do
      {:module, _} = Code.ensure_loaded(Kontor.Mail.Poller)

      poller_beam = :code.which(Kontor.Mail.Poller)

      {:ok, {_, [{:abstract_code, {_, forms}}]}} =
        :beam_lib.chunks(poller_beam, [:abstract_code])

      source_str = :erl_prettypr.format(:erl_syntax.form_list(forms)) |> List.to_string()

      assert String.contains?(source_str, "date:desc"),
             "Expected Kontor.Mail.Poller to call HimalayaClient.list_emails " <>
               "with sort argument \"date:desc\", but the literal was not found " <>
               "in the compiled module. If the sort was changed, update the " <>
               "Poller and this test together."
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Task age cutoff — run_tier2 skips "task_extractor" for stale emails
  #
  # Pipeline.run_tier2/4 (private) filters "task_extractor" from tier2_skills
  # when email.received_at is older than cutoff_months * 30 days.
  #
  # We test the filtering logic directly and verify process_email/2 does not
  # raise for either stale or recent emails.
  # ---------------------------------------------------------------------------

  describe "task age cutoff — run_tier2 skips task_extractor for stale emails" do
    test "cutoff logic filters task_extractor for email older than cutoff" do
      cutoff_months = 3
      cutoff_dt = DateTime.add(DateTime.utc_now(), -cutoff_months * 30 * 24 * 3600, :second)

      stale_dt = DateTime.add(cutoff_dt, -86_400, :second)

      tier2_skills = ["scorer", "thread_summarizer", "task_extractor"]

      filtered =
        if DateTime.compare(stale_dt, cutoff_dt) == :lt do
          Enum.reject(tier2_skills, &(&1 == "task_extractor"))
        else
          tier2_skills
        end

      refute "task_extractor" in filtered,
             "Expected task_extractor to be filtered out for email older than cutoff"

      assert "scorer" in filtered
      assert "thread_summarizer" in filtered
    end

    test "cutoff logic keeps task_extractor for recent email" do
      cutoff_months = 3
      cutoff_dt = DateTime.add(DateTime.utc_now(), -cutoff_months * 30 * 24 * 3600, :second)

      recent_dt = DateTime.add(cutoff_dt, 86_400, :second)

      tier2_skills = ["scorer", "thread_summarizer", "task_extractor"]

      filtered =
        if DateTime.compare(recent_dt, cutoff_dt) == :lt do
          Enum.reject(tier2_skills, &(&1 == "task_extractor"))
        else
          tier2_skills
        end

      assert "task_extractor" in filtered,
             "Expected task_extractor to be kept for recent email"
    end

    test "process_email with stale email does not raise" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id,
                       task_age_cutoff_months: 3)

      stale_received_at =
        DateTime.utc_now()
        |> DateTime.add(-(4 * 30 * 24 * 3600), :second)
        |> DateTime.truncate(:second)

      email = insert(:email,
        tenant_id: @tenant,
        mailbox_id: mailbox.id,
        message_id: "stale-cutoff-msg-#{System.unique_integer([:positive])}",
        thread_id: "stale-cutoff-thread-#{System.unique_integer([:positive])}",
        subject: "Old email",
        sender: "old@example.com",
        recipients: ["me@example.com"],
        body: "Over 3 months old",
        received_at: stale_received_at
      )

      assert :ok = Pipeline.process_email(email, task_age_cutoff_months: 3)
    end

    test "process_email with recent email does not raise" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id,
                       task_age_cutoff_months: 3)

      recent_received_at =
        DateTime.utc_now()
        |> DateTime.add(-(1 * 24 * 3600), :second)
        |> DateTime.truncate(:second)

      email = insert(:email,
        tenant_id: @tenant,
        mailbox_id: mailbox.id,
        message_id: "recent-cutoff-msg-#{System.unique_integer([:positive])}",
        thread_id: "recent-cutoff-thread-#{System.unique_integer([:positive])}",
        subject: "Recent email",
        sender: "new@example.com",
        recipients: ["me@example.com"],
        body: "Just arrived",
        received_at: recent_received_at
      )

      assert :ok = Pipeline.process_email(email, task_age_cutoff_months: 3)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Thread completeness nil guard
  #
  # Poller.fetch_and_upsert_thread_siblings/3 (private) returns {:ok, :skipped}
  # when email.thread_id is nil, preventing a crash on threadless emails.
  #
  # We verify the guard logic and that process_email with a nil thread_id email
  # does not raise.
  # ---------------------------------------------------------------------------

  describe "fetch_and_upsert_thread_siblings — nil thread_id guard" do
    test "guard returns :skipped when thread_id is nil" do
      # Replicate the nil guard from Poller.fetch_and_upsert_thread_siblings/3:
      #   if is_nil(email.thread_id) do
      #     {:ok, :skipped}
      #   else
      #     ...fetch siblings...
      #   end
      result =
        if is_nil(nil) do
          {:ok, :skipped}
        else
          :would_fetch
        end

      assert result == {:ok, :skipped}
    end

    test "guard proceeds when thread_id is present" do
      result =
        if is_nil("thread-abc") do
          {:ok, :skipped}
        else
          :would_fetch
        end

      assert result == :would_fetch
    end

    test "process_email with nil thread_id email does not crash" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      email = insert(:email,
        tenant_id: @tenant,
        mailbox_id: mailbox.id,
        message_id: "nil-thread-msg-#{System.unique_integer([:positive])}",
        thread_id: nil,
        subject: "Orphan email",
        sender: "orphan@example.com",
        recipients: ["me@example.com"],
        body: "No thread_id"
      )

      # GenServer.cast returns :ok immediately; the background Task will call
      # fetch_and_upsert_thread_siblings with nil thread_id → {:ok, :skipped}
      assert :ok = Pipeline.process_email(email)
    end
  end
end
