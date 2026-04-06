defmodule Kontor.Mail do
  @moduledoc "Context module for email, thread, and draft operations."

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.Mail.{Email, Thread, ScheduledSend}

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

  defp atomize(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
