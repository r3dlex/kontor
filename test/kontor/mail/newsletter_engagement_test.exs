defmodule Kontor.Mail.NewsletterEngagementTest do
  use Kontor.DataCase, async: true
  alias Kontor.Mail

  @tenant "test-newsletter-engagement"

  describe "update_newsletter_engagement/4" do
    test "sets auto_archive after 2 consecutive unreads" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      Mail.update_newsletter_engagement(mailbox.id, "newsletters.com", @tenant)
      Mail.update_newsletter_engagement(mailbox.id, "newsletters.com", @tenant)

      {:ok, engagement} = Mail.update_newsletter_engagement(mailbox.id, "newsletters.com", @tenant)
      assert engagement.auto_archive == true
      assert engagement.consecutive_unread == 3
    end

    test "resets consecutive_unread on read" do
      user = insert(:user, tenant_id: @tenant)
      mailbox = insert(:mailbox, tenant_id: @tenant, user_id: user.id)

      Mail.update_newsletter_engagement(mailbox.id, "newsletters.com", @tenant)
      Mail.update_newsletter_engagement(mailbox.id, "newsletters.com", @tenant)
      {:ok, engagement} = Mail.update_newsletter_engagement(mailbox.id, "newsletters.com", @tenant, read: true)

      assert engagement.consecutive_unread == 0
      assert engagement.auto_archive == false
    end
  end
end
