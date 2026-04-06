defmodule Kontor.Factory do
  @moduledoc """
  ExMachina factory for all Kontor schemas.

  Usage notes:
  - Simple factories (Task, Thread, Contact, CalendarEvent, Skill) can be
    inserted with `insert(:task, tenant_id: "my-tenant")` directly.
  - Factories with foreign keys (Email, Mailbox, Credential, ChatSession,
    ChatMessage) insert dependencies at factory time. When overriding tenant_id,
    also pass matching foreign key IDs:
      user = insert(:user, tenant_id: t)
      mailbox = insert(:mailbox, tenant_id: t, user_id: user.id)
      insert(:email, tenant_id: t, mailbox_id: mailbox.id)
  """

  use ExMachina.Ecto, repo: Kontor.Repo

  alias Kontor.Accounts.{User, Mailbox, Credential}
  alias Kontor.Mail.{Email, Thread}
  alias Kontor.Contacts.{Contact, ContactRelationship}
  alias Kontor.Calendar.CalendarEvent
  alias Kontor.AI.Skill
  alias Kontor.Chat.{ChatSession, ChatMessage}
  alias Kontor.Tasks.Task

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  def user_factory do
    %User{
      tenant_id: sequence(:user_tenant, &"tenant-user-#{&1}"),
      email: sequence(:user_email, &"user#{&1}@example.com"),
      name: "Test User"
    }
  end

  # ---------------------------------------------------------------------------
  # Mailbox
  # ---------------------------------------------------------------------------

  def mailbox_factory do
    tenant_id = sequence(:mb_tenant, &"tenant-mb-#{&1}")
    user = insert(:user, tenant_id: tenant_id)

    %Mailbox{
      tenant_id: tenant_id,
      provider: :google,
      email_address: sequence(:mb_email, &"mailbox#{&1}@example.com"),
      user_id: user.id,
      polling_interval_seconds: 60,
      task_age_cutoff_months: 3,
      read_only: false
    }
  end

  # ---------------------------------------------------------------------------
  # Credential
  # ---------------------------------------------------------------------------

  def credential_factory do
    tenant_id = sequence(:cred_tenant, &"tenant-cred-#{&1}")
    user = insert(:user, tenant_id: tenant_id)

    %Credential{
      tenant_id: tenant_id,
      provider: :google,
      user_id: user.id,
      expires_at: DateTime.add(DateTime.utc_now(), 3600) |> DateTime.truncate(:second)
    }
  end

  # ---------------------------------------------------------------------------
  # Email
  # ---------------------------------------------------------------------------

  def email_factory do
    tenant_id = sequence(:email_tenant, &"tenant-email-#{&1}")
    user = insert(:user, tenant_id: tenant_id)
    mailbox = insert(:mailbox, tenant_id: tenant_id, user_id: user.id)

    %Email{
      tenant_id: tenant_id,
      message_id: sequence(:msg_id, &"msg-#{&1}@example.com"),
      thread_id: sequence(:email_thread_id, &"thread-#{&1}"),
      subject: "Test Subject",
      sender: "sender@example.com",
      recipients: ["recipient@example.com"],
      body: "Test email body",
      received_at: DateTime.utc_now() |> DateTime.truncate(:second),
      mailbox_id: mailbox.id
    }
  end

  # ---------------------------------------------------------------------------
  # Thread
  # ---------------------------------------------------------------------------

  def thread_factory do
    %Thread{
      tenant_id: sequence(:thread_tenant, &"tenant-thread-#{&1}"),
      thread_id: sequence(:ext_thread_id, &"ext-thread-#{&1}"),
      markdown_content: "# Thread Summary\n\nTest content.",
      last_updated: DateTime.utc_now() |> DateTime.truncate(:second),
      score_urgency: 0.5,
      score_action: 0.4,
      score_authority: 0.3,
      score_momentum: 0.6,
      composite_score: 0.45
    }
  end

  # ---------------------------------------------------------------------------
  # Contact
  # ---------------------------------------------------------------------------

  def contact_factory do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Contact{
      tenant_id: sequence(:contact_tenant, &"tenant-contact-#{&1}"),
      email_address: sequence(:contact_email, &"contact#{&1}@example.com"),
      display_name: "Contact Name",
      organization: "ACME Corp",
      role: "Engineer",
      importance_weight: 0.5,
      first_seen: now,
      last_seen: now
    }
  end

  # ---------------------------------------------------------------------------
  # ContactRelationship
  # ---------------------------------------------------------------------------

  def contact_relationship_factory do
    %ContactRelationship{
      tenant_id: sequence(:rel_tenant, &"tenant-rel-#{&1}"),
      contact_a_id: Ecto.UUID.generate(),
      contact_b_id: Ecto.UUID.generate(),
      relationship_type: "colleague",
      weight: 0.7,
      last_updated: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  # ---------------------------------------------------------------------------
  # CalendarEvent
  # ---------------------------------------------------------------------------

  def calendar_event_factory do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %CalendarEvent{
      tenant_id: sequence(:cal_tenant, &"tenant-cal-#{&1}"),
      provider: :google,
      external_id: sequence(:ext_cal_id, &"gcal-#{&1}"),
      title: "Team Standup",
      attendees: ["alice@example.com", "bob@example.com"],
      start_time: now,
      end_time: DateTime.add(now, 3600)
    }
  end

  # ---------------------------------------------------------------------------
  # Skill
  # ---------------------------------------------------------------------------

  def skill_factory do
    %Skill{
      tenant_id: sequence(:skill_tenant, &"tenant-skill-#{&1}"),
      namespace: "shared",
      name: sequence(:skill_name, &"skill-#{&1}"),
      version: 1,
      content: "---\nname: test\n---\n# Test Skill\nDo stuff.",
      author: :system,
      locked: false,
      active: true
    }
  end

  # ---------------------------------------------------------------------------
  # ChatSession
  # ---------------------------------------------------------------------------

  def chat_session_factory do
    tenant_id = sequence(:session_tenant, &"tenant-session-#{&1}")
    user = insert(:user, tenant_id: tenant_id)

    %ChatSession{
      tenant_id: tenant_id,
      view_origin: "inbox",
      started_at: DateTime.utc_now() |> DateTime.truncate(:second),
      user_id: user.id
    }
  end

  # ---------------------------------------------------------------------------
  # ChatMessage
  # ---------------------------------------------------------------------------

  def chat_message_factory do
    tenant_id = sequence(:msg_tenant, &"tenant-msg-#{&1}")
    user = insert(:user, tenant_id: tenant_id)
    {:ok, session} = Kontor.Chat.get_or_create_session(user.id, "inbox", tenant_id)

    %ChatMessage{
      tenant_id: tenant_id,
      role: :user,
      content: "Hello, AI assistant",
      view_context: %{},
      session_id: session.id,
      user_id: user.id
    }
  end

  # ---------------------------------------------------------------------------
  # Task
  # ---------------------------------------------------------------------------

  def task_factory do
    %Task{
      tenant_id: sequence(:task_tenant, &"tenant-task-#{&1}"),
      task_type: :reply,
      title: "Reply to Alice",
      description: "Need to follow up on proposal",
      importance: 0.7,
      status: :created,
      confidence: 0.6
    }
  end
end
