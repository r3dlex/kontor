defmodule Kontor.Mail.EmailLabelTest do
  use Kontor.DataCase, async: true
  alias Kontor.Mail.EmailLabel

  @tenant "test-email-label"

  describe "changeset/2" do
    test "valid changeset with required fields" do
      user = insert(:user, tenant_id: @tenant)
      email = insert(:email, tenant_id: @tenant, mailbox_id: insert(:mailbox, tenant_id: @tenant, user_id: user.id).id)
      attrs = %{tenant_id: @tenant, email_id: email.id, inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      assert changeset = EmailLabel.changeset(%EmailLabel{}, attrs)
      assert changeset.valid?
    end

    test "validates priority_score range" do
      user = insert(:user, tenant_id: @tenant)
      email = insert(:email, tenant_id: @tenant, mailbox_id: insert(:mailbox, tenant_id: @tenant, user_id: user.id).id)
      base = %{tenant_id: @tenant, email_id: email.id, inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)}

      assert EmailLabel.changeset(%EmailLabel{}, Map.put(base, :priority_score, -1)).valid? == false
      assert EmailLabel.changeset(%EmailLabel{}, Map.put(base, :priority_score, 101)).valid? == false
      assert EmailLabel.changeset(%EmailLabel{}, Map.put(base, :priority_score, 0)).valid?
      assert EmailLabel.changeset(%EmailLabel{}, Map.put(base, :priority_score, 100)).valid?
    end
  end
end
