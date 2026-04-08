defmodule Kontor.AI.PipelineLabelerTest do
  @moduledoc """
  Tests for the labeler skill post-processing in Pipeline.post_process/4.
  Verifies that labeler results are persisted as EmailLabel records.
  """
  use Kontor.DataCase, async: true

  alias Kontor.AI.Pipeline
  alias Kontor.Mail

  @tenant "tenant-pipeline-labeler-test"

  setup do
    if :ets.whereis(:minimax_response_cache) == :undefined do
      Kontor.AI.MinimaxClient.start_cache()
    end
    :ok
  end

  describe "process_email/2 labeler integration" do
    test "process_email does not crash for email with labeler-style tier1 output" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email,
        tenant_id: @tenant,
        mailbox_id: mailbox.id,
        message_id: "labeler-test-#{System.unique_integer([:positive])}",
        thread_id: "labeler-thread-#{System.unique_integer([:positive])}",
        subject: "Please review the Q4 budget",
        sender: "ceo@example.com",
        recipients: ["me@example.com"],
        body: "Need your approval by Friday"
      )

      assert :ok = Pipeline.process_email(email, task_age_cutoff_months: 3)
    end
  end

  describe "upsert_email_labels via Mail context" do
    test "upsert_email_labels persists labels and priority_score" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email,
        tenant_id: @tenant,
        mailbox_id: mailbox.id,
        message_id: "label-upsert-#{System.unique_integer([:positive])}"
      )

      attrs = %{
        email_id: email.id,
        labels: ["Direct", "VIP", "High-Priority"],
        priority_score: 82,
        has_actionable_task: true,
        task_summary: "Review Q4 budget",
        ai_confidence: 0.91,
        ai_reasoning: "Direct message from CEO",
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      assert {:ok, label} = Mail.upsert_email_labels(attrs, @tenant)
      assert label.labels == ["Direct", "VIP", "High-Priority"]
      assert label.priority_score == 82
      assert label.has_actionable_task == true
    end

    test "upsert_email_labels overwrites existing record on conflict" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email,
        tenant_id: @tenant,
        mailbox_id: mailbox.id,
        message_id: "label-upsert-conflict-#{System.unique_integer([:positive])}"
      )

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      base = %{email_id: email.id, labels: ["Newsletter"], priority_score: 20,
               has_actionable_task: false, inserted_at: now}

      {:ok, _} = Mail.upsert_email_labels(base, @tenant)

      updated = %{email_id: email.id, labels: ["Direct", "Urgent"], priority_score: 90,
                  has_actionable_task: true, inserted_at: now}
      {:ok, label} = Mail.upsert_email_labels(updated, @tenant)

      assert label.labels == ["Direct", "Urgent"]
      assert label.priority_score == 90
    end
  end
end
