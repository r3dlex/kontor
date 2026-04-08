defmodule Kontor.Mail do
  @moduledoc "Context module for email, thread, and draft operations."

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.Mail.{Email, Thread, ScheduledSend, EmailLabel, SenderRule, FolderCorrection, NewsletterEngagement, FolderSuggestion}

  require Logger

  # --- Emails ---

  def get_email(id, tenant_id) do
    case Repo.get_by(Email, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      email -> {:ok, email}
    end
  end

  def list_thread_emails(thread_id, tenant_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from e in Email,
      where: e.tenant_id == ^tenant_id and e.thread_id == ^thread_id,
      order_by: [asc: :received_at],
      limit: ^limit
    )
  end

  def sample_thread_emails(thread_id, tenant_id, count \\ 3) do
    all = list_thread_emails(thread_id, tenant_id)
    Enum.take_random(all, min(count, length(all)))
  end

  # --- Threads ---

  def get_thread(id, tenant_id) do
    case Repo.get_by(Thread, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      thread -> {:ok, thread}
    end
  end

  def get_thread_by_thread_id(thread_id, tenant_id) do
    Repo.get_by(Thread, thread_id: thread_id, tenant_id: tenant_id)
  end

  def update_thread_markdown(thread_id, content, tenant_id) do
    case Repo.get_by(Thread, thread_id: thread_id, tenant_id: tenant_id) do
      nil ->
        %Thread{}
        |> Thread.changeset(%{tenant_id: tenant_id, thread_id: thread_id,
                               markdown_content: content, last_updated: DateTime.utc_now()})
        |> Repo.insert()

      thread ->
        thread
        |> Thread.changeset(%{markdown_content: content, last_updated: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  def update_thread_scores(thread_id, scores, tenant_id) do
    case Repo.get_by(Thread, thread_id: thread_id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      thread ->
        attrs = Map.take(scores, [:score_urgency, :score_action, :score_authority, :score_momentum])
        composite = Map.values(attrs) |> Enum.sum() |> then(&(&1 / max(map_size(attrs), 1)))

        thread
        |> Thread.changeset(Map.put(attrs, :composite_score, composite))
        |> Repo.update()
    end
  end

  # --- Drafts / Scheduled Sends ---

  def create_draft(params, tenant_id) do
    attrs = Map.merge(params, %{"tenant_id" => tenant_id})
    %ScheduledSend{}
    |> ScheduledSend.changeset(attrs)
    |> Repo.insert()
  end

  def send_or_schedule_draft(id, nil, tenant_id) do
    with {:ok, draft} <- get_draft(id, tenant_id) do
      Kontor.MCP.HimalayaClient.send_email(draft)
      draft |> ScheduledSend.changeset(%{status: :sent, sent_at: DateTime.utc_now()}) |> Repo.update()
      {:ok, :sent}
    end
  end

  def send_or_schedule_draft(id, scheduled_at, tenant_id) do
    with {:ok, draft} <- get_draft(id, tenant_id),
         {:ok, dt, _offset} <- DateTime.from_iso8601(scheduled_at) do
      draft
      |> ScheduledSend.changeset(%{scheduled_at: dt, status: :pending})
      |> Repo.update()

      {:ok, :scheduled}
    end
  end

  defp get_draft(id, tenant_id) do
    case Repo.get_by(ScheduledSend, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      draft -> {:ok, draft}
    end
  end

  def list_drafts(tenant_id) do
    Repo.all(from s in ScheduledSend,
      where: s.tenant_id == ^tenant_id and s.status == :pending,
      order_by: [desc: :inserted_at])
  end

  def update_thread(thread, attrs, _tenant_id) do
    thread
    |> Thread.changeset(atomize(attrs))
    |> Repo.update()
  end

  def manage_folder(_params, _tenant_id) do
    # Delegated to Himalaya MCP
    {:ok, :delegated}
  end

  # --- Email Reference Storage helpers ---

  @doc """
  Atomic CAS: sets markdown_stale = false on the thread only if it is currently true.
  Returns {:ok, :updated} when this process won the race, {:ok, :already_processed}
  when another process already cleared the flag.
  """
  def mark_thread_processed(thread_id, tenant_id) do
    {count, _} =
      Repo.update_all(
        from(t in Thread,
          where: t.thread_id == ^thread_id and t.tenant_id == ^tenant_id and t.markdown_stale == true
        ),
        set: [markdown_stale: false]
      )

    if count == 1 do
      {:ok, :updated}
    else
      {:ok, :already_processed}
    end
  end

  @doc """
  Nils out the body and raw_headers of an email after successful pipeline processing,
  and sets processed_at as an audit timestamp.
  """
  def clear_email_body(%Email{} = email) do
    email
    |> Email.changeset(%{body: nil, raw_headers: nil, processed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update()
  end

  @doc """
  Returns threads with markdown_stale = true for a tenant, ordered oldest-first.
  Accepts an optional :limit keyword (default 50).
  """
  def stale_threads(tenant_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from t in Thread,
      where: t.tenant_id == ^tenant_id and t.markdown_stale == true,
      order_by: [asc: t.updated_at],
      limit: ^limit
    )
  end

  # --- Folder Organization ---

  def record_folder_correction(attrs, tenant_id) do
    attrs = Map.merge(attrs, %{
      tenant_id: tenant_id,
      recorded_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    result = %FolderCorrection{}
    |> FolderCorrection.changeset(attrs)
    |> Repo.insert()

    case result do
      {:ok, correction} ->
        maybe_promote_sender_rule(attrs[:sender], attrs[:mailbox_id], attrs[:to_folder], tenant_id)
        {:ok, correction}
      error -> error
    end
  end

  defp maybe_promote_sender_rule(nil, _mailbox_id, _folder, _tenant_id), do: :ok
  defp maybe_promote_sender_rule(sender, mailbox_id, folder, tenant_id) do
    count = Repo.aggregate(
      from(fc in FolderCorrection,
        where: fc.mailbox_id == ^mailbox_id and fc.sender == ^sender and fc.to_folder == ^folder),
      :count, :id
    )

    if count >= 3 do
      upsert_sender_rule(%{
        tenant_id: tenant_id,
        mailbox_id: mailbox_id,
        sender_pattern: sender,
        rule_type: "folder_override",
        rule_data: %{"folder" => folder},
        confidence: "confident",
        correction_count: count,
        source: "user_correction",
        active: true
      }, tenant_id)
    else
      :ok
    end
  end

  def get_sender_rules(mailbox_id, tenant_id) do
    Repo.all(from sr in SenderRule,
      where: sr.mailbox_id == ^mailbox_id and sr.tenant_id == ^tenant_id and sr.active == true)
  end

  def upsert_email_labels(attrs, tenant_id) do
    attrs = Map.put(attrs, :tenant_id, tenant_id)
    attrs = Map.put_new(attrs, :inserted_at, DateTime.utc_now() |> DateTime.truncate(:second))

    %EmailLabel{}
    |> EmailLabel.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:labels, :priority_score, :has_actionable_task,
                                :task_summary, :task_deadline, :ai_confidence, :ai_reasoning]},
      conflict_target: :email_id
    )
  end

  def upsert_sender_rule(attrs, _tenant_id) do
    changeset = %SenderRule{} |> SenderRule.changeset(attrs)

    Repo.insert(changeset,
      on_conflict: {:replace, [:rule_type, :rule_data, :confidence, :correction_count,
                                :source, :active, :updated_at]},
      conflict_target: [:tenant_id, :mailbox_id, :sender_pattern]
    )
  end

  def create_folder_suggestion(attrs, tenant_id) do
    attrs = Map.merge(attrs, %{
      tenant_id: tenant_id,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })

    %FolderSuggestion{}
    |> FolderSuggestion.changeset(attrs)
    |> Repo.insert()
  end

  def get_email_labels(email_id, tenant_id) do
    Repo.get_by(EmailLabel, email_id: email_id, tenant_id: tenant_id)
  end

  def update_newsletter_engagement(mailbox_id, sender_domain, tenant_id, opts \\ []) do
    read? = Keyword.get(opts, :read, false)

    existing = Repo.get_by(NewsletterEngagement,
      mailbox_id: mailbox_id, sender_domain: sender_domain)

    new_consecutive = if read?, do: 0, else: (existing && existing.consecutive_unread || 0) + 1
    auto_archive = new_consecutive >= 2

    attrs = %{
      tenant_id: tenant_id,
      mailbox_id: mailbox_id,
      sender_domain: sender_domain,
      consecutive_unread: new_consecutive,
      last_received_at: DateTime.utc_now() |> DateTime.truncate(:second),
      auto_archive: auto_archive
    }

    changeset = %NewsletterEngagement{} |> NewsletterEngagement.changeset(attrs)

    Repo.insert(changeset,
      on_conflict: {:replace, [:consecutive_unread, :last_received_at, :auto_archive, :updated_at]},
      conflict_target: [:mailbox_id, :sender_domain]
    )
  end

  def active_folder_count(mailbox_id, tenant_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)

    Repo.aggregate(
      from(fs in FolderSuggestion,
        where: fs.mailbox_id == ^mailbox_id and fs.tenant_id == ^tenant_id
               and fs.inserted_at > ^cutoff
               and not is_nil(fs.suggested_folder),
        select: fs.suggested_folder,
        distinct: true),
      :count
    )
  end

  def weekly_folder_volume(mailbox_id, folder_name, tenant_id) do
    cutoff = DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)

    Repo.aggregate(
      from(fs in FolderSuggestion,
        where: fs.mailbox_id == ^mailbox_id and fs.tenant_id == ^tenant_id
               and fs.suggested_folder == ^folder_name
               and fs.inserted_at > ^cutoff),
      :count, :id
    )
  end

  defp atomize(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
