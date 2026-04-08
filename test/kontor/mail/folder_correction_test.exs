defmodule Kontor.Mail.FolderCorrectionTest do
  use Kontor.DataCase, async: true
  alias Kontor.Mail

  @tenant "test-folder-correction"

  describe "record_folder_correction/2" do
    test "creates a correction record" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      email = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id)

      attrs = %{mailbox_id: mailbox.id, email_id: email.id, from_folder: "Inbox",
                to_folder: "Archive", sender: "boss@example.com",
                sender_domain: "example.com"}

      assert {:ok, correction} = Mail.record_folder_correction(attrs, @tenant)
      assert correction.to_folder == "Archive"
    end

    test "promotes sender rule after 3 corrections" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      for _ <- 1..3 do
        email = insert(:email, tenant_id: @tenant, mailbox_id: mailbox.id,
                        message_id: "msg-#{System.unique_integer([:positive])}")
        Mail.record_folder_correction(
          %{mailbox_id: mailbox.id, email_id: email.id, from_folder: "Inbox",
            to_folder: "Archive", sender: "promoteme@example.com", sender_domain: "example.com"},
          @tenant
        )
      end

      rules = Mail.get_sender_rules(mailbox.id, @tenant)
      assert Enum.any?(rules, &(&1.sender_pattern == "promoteme@example.com" and &1.confidence == "confident"))
    end
  end
end
