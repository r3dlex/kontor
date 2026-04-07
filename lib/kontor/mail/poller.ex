defmodule Kontor.Mail.Poller do
  @moduledoc "Polls Himalaya MCP for new emails on a per-mailbox interval."
  use GenServer
  require Logger

  import Ecto.Query

  alias Kontor.Mail.{Email, Thread}
  alias Kontor.Repo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_poll(5_000)
    {:ok, %{last_seen: %{}}}
  end

  @impl true
  def handle_info(:poll, state) do
    new_last_seen = poll_all_mailboxes(state.last_seen)
    interval = Application.get_env(:kontor, :mail)[:polling_interval_ms] || 60_000
    schedule_poll(interval)
    {:noreply, %{state | last_seen: new_last_seen}}
  end

  defp poll_all_mailboxes(last_seen) do
    mailboxes = Repo.all(from m in Kontor.Accounts.Mailbox, where: m.active == true)

    Enum.reduce(mailboxes, last_seen, fn mailbox, acc ->
      case fetch_new_emails(mailbox, acc[mailbox.id]) do
        {:ok, emails, new_cursor} ->
          Enum.each(emails, &process_email(&1, mailbox))
          Map.put(acc, mailbox.id, new_cursor)
        {:error, reason} ->
          Logger.warning("Poller error for mailbox #{mailbox.id}: #{inspect(reason)}")
          acc
      end
    end)
  end

  defp fetch_new_emails(mailbox, _cursor) do
    case Kontor.MCP.HimalayaClient.list_emails(mailbox.himalaya_config, "INBOX", 20) do
      {:ok, emails} -> {:ok, emails, DateTime.utc_now()}
      error -> error
    end
  end

  defp process_email(raw_email, mailbox) do
    tenant_id = mailbox.tenant_id

    attrs = %{
      tenant_id: tenant_id,
      mailbox_id: mailbox.id,
      message_id: raw_email["id"],
      thread_id: raw_email["thread_id"],
      subject: raw_email["subject"],
      sender: raw_email["from"],
      recipients: raw_email["to"] || [],
      body: raw_email["body"],
      received_at: parse_dt(raw_email["date"])
    }

    case Repo.insert(Email.changeset(%Email{}, attrs),
           on_conflict: :nothing, conflict_target: [:tenant_id, :message_id]) do
      {:ok, %Email{id: nil}} ->
        # Duplicate: fetch existing email; only call pipeline if thread is stale
        existing = Repo.get_by(Email, tenant_id: tenant_id, message_id: attrs.message_id)
        if existing do
          thread = existing.thread_id && Repo.get_by(Thread, thread_id: existing.thread_id, tenant_id: tenant_id)
          if thread && thread.markdown_stale do
            Kontor.AI.Pipeline.process_email(existing)
          end
          Kontor.Contacts.OrganizationWorker.process_email_contacts(existing, tenant_id)
        end

      {:ok, %Email{id: _id} = email} ->
        # New email: upsert thread to ensure it exists with markdown_stale = true
        upsert_thread(email, tenant_id)
        Kontor.AI.Pipeline.process_email(email)
        Kontor.Contacts.OrganizationWorker.process_email_contacts(email, tenant_id)

      _ ->
        :ok
    end
  end

  defp upsert_thread(email, tenant_id) do
    thread_attrs = %{
      tenant_id: tenant_id,
      thread_id: email.thread_id,
      markdown_stale: true,
      last_updated: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    Repo.insert(
      Thread.changeset(%Thread{}, thread_attrs),
      on_conflict: [set: [markdown_stale: true]],
      conflict_target: [:tenant_id, :thread_id]
    )
  end

  defp parse_dt(nil), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp parse_dt(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp schedule_poll(ms) do
    Process.send_after(self(), :poll, ms)
  end
end
