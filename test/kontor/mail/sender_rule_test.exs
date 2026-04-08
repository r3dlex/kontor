defmodule Kontor.Mail.SenderRuleTest do
  use Kontor.DataCase, async: true
  alias Kontor.Mail.SenderRule

  @tenant "test-sender-rule"

  describe "changeset/2" do
    test "validates rule_type inclusion" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      base = %{tenant_id: @tenant, mailbox_id: mailbox.id, sender_pattern: "example.com", rule_type: "invalid"}
      changeset = SenderRule.changeset(%SenderRule{}, base)
      refute changeset.valid?
      assert errors_on(changeset).rule_type
    end

    test "valid with folder_override rule_type" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)
      attrs = %{tenant_id: @tenant, mailbox_id: mailbox.id, sender_pattern: "example.com",
                rule_type: "folder_override", confidence: "confident"}
      assert SenderRule.changeset(%SenderRule{}, attrs).valid?
    end
  end
end
