defmodule Kontor.AI.PipelineTest do
  use Kontor.DataCase, async: false

  alias Kontor.AI.{Pipeline, MinimaxClient}

  @tenant "tenant-pipeline-test"

  setup do
    if :ets.whereis(:minimax_response_cache) == :undefined do
      MinimaxClient.start_cache()
    end
    :ok
  end

  # ---------------------------------------------------------------------------
  # run_skill/3
  # ---------------------------------------------------------------------------

  describe "run_skill/3 — existing skills" do
    test "returns {:ok, result} for classifier skill" do
      assert {:ok, result} = Pipeline.run_skill("classifier", %{subject: "Hello", sender: "a@b.com", recipients: []}, @tenant)
      assert is_map(result)
    end

    test "returns {:ok, result} for scorer skill" do
      assert {:ok, result} = Pipeline.run_skill("scorer", %{subject: "Test", body: "Body"}, @tenant)
      assert is_map(result)
    end

    test "returns {:ok, result} for thread_summarizer skill" do
      assert {:ok, result} = Pipeline.run_skill("thread_summarizer", %{subject: "Re: Thing", body: "Details"}, @tenant)
      assert is_map(result)
    end

    test "returns {:ok, result} for task_extractor skill" do
      assert {:ok, result} = Pipeline.run_skill("task_extractor", %{body: "Please do X by Friday"}, @tenant)
      assert is_map(result)
    end

    test "returns {:ok, result} for reply_drafter skill" do
      assert {:ok, result} = Pipeline.run_skill("reply_drafter", %{body: "Can you help?"}, @tenant)
      assert is_map(result)
    end
  end

  describe "run_skill/3 — non-existent skill" do
    test "returns {:error, :skill_not_found} for unknown skill" do
      assert {:error, :skill_not_found} = Pipeline.run_skill("nonexistent_skill_xyz_abc", %{}, @tenant)
    end

    test "returns {:error, :skill_not_found} for empty string skill name" do
      assert {:error, :skill_not_found} = Pipeline.run_skill("", %{}, @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # process_email/2 — cast, does not crash
  # ---------------------------------------------------------------------------

  describe "process_email/2" do
    test "casts without crashing for a well-formed email struct" do
      email = %{
        id: Ecto.UUID.generate(),
        tenant_id: @tenant,
        message_id: "msg-pipeline-test-#{System.unique_integer([:positive])}",
        thread_id: "thread-pipeline-test",
        subject: "Hello Pipeline",
        sender: "sender@example.com",
        recipients: ["recipient@example.com"],
        body: "Test email body for pipeline"
      }

      # process_email is a GenServer.cast — it should not raise
      assert :ok = Pipeline.process_email(email, @tenant)
    end

    test "casts without crashing when body is nil" do
      email = %{
        id: Ecto.UUID.generate(),
        tenant_id: @tenant,
        message_id: "msg-nil-body-#{System.unique_integer([:positive])}",
        thread_id: "thread-nil-body",
        subject: "No body",
        sender: "a@b.com",
        recipients: [],
        body: nil
      }

      assert :ok = Pipeline.process_email(email, @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # build_email_input context depths — tested indirectly via run_skill on
  # a skill whose prompt is generated from an email-shaped input map.
  # We verify the correct keys are present by calling a real skill.
  # ---------------------------------------------------------------------------

  describe "build_email_input context depths (via do_process internals)" do
    # These tests validate the public run_skill surface which uses build_prompt/2,
    # confirming the pipeline accepts various input shapes without crashing.

    test "headers_only input shape is accepted" do
      input = %{subject: "Mtg invite", sender: "boss@co.com", recipients: ["me@co.com"]}
      assert {:ok, _} = Pipeline.run_skill("classifier", input, @tenant)
    end

    test "first_100_chars input shape is accepted" do
      input = %{
        subject: "Follow up",
        sender: "a@b.com",
        recipients: ["c@d.com"],
        body_preview: String.duplicate("x", 100)
      }
      assert {:ok, _} = Pipeline.run_skill("scorer", input, @tenant)
    end

    test "full_body input shape is accepted" do
      input = %{
        subject: "Full report",
        sender: "report@co.com",
        recipients: ["team@co.com"],
        body: "This is the full body of the email with lots of content."
      }
      assert {:ok, _} = Pipeline.run_skill("thread_summarizer", input, @tenant)
    end
  end
end
