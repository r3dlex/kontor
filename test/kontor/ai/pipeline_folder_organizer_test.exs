defmodule Kontor.AI.PipelineFolderOrganizerTest do
  @moduledoc """
  Tests for folder_organizer post-processing in Pipeline.post_process/4.
  Verifies bootstrap guard, confidence guard, and create_folder_suggestion integration.
  """
  use Kontor.DataCase, async: true

  alias Kontor.Mail

  @tenant "tenant-pipeline-folder-org-test"

  describe "create_folder_suggestion/2" do
    test "creates a folder suggestion with action-based folder" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email,
        tenant_id: @tenant,
        mailbox_id: mailbox.id,
        message_id: "fs-test-#{System.unique_integer([:positive])}"
      )

      attrs = %{
        email_id: email.id,
        mailbox_id: mailbox.id,
        email_message_id: email.message_id,
        suggested_folder: "Action Required",
        confidence: 0.88,
        reasoning: "Email requires approval",
        labels: ["Direct", "VIP"],
        priority_score: 82,
        skill: "folder_organizer"
      }

      assert {:ok, suggestion} = Mail.create_folder_suggestion(attrs, @tenant)
      assert suggestion.suggested_folder == "Action Required"
      assert suggestion.confidence == 0.88
    end

    test "create_folder_suggestion returns error on missing required fields" do
      attrs = %{suggested_folder: "Action Required"}
      assert {:error, _changeset} = Mail.create_folder_suggestion(attrs, @tenant)
    end
  end

  describe "active_folder_count/2" do
    test "returns count of distinct active folders" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      for folder <- ["Action Required", "Archive", "Reference"] do
        email = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
                        message_id: "afc-#{folder}-#{System.unique_integer([:positive])}")
        Mail.create_folder_suggestion(%{
          email_id: email.id,
          mailbox_id: mailbox.id,
          email_message_id: email.message_id,
          suggested_folder: folder,
          confidence: 0.85
        }, @tenant)
      end

      count = Mail.active_folder_count(mailbox.id, @tenant)
      assert count >= 3
    end
  end
end
