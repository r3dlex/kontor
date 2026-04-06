defmodule Kontor.Mail.Importer do
  @moduledoc "Background import worker for historical emails."
  use GenServer
  require Logger

  @rate_limit_ms 200  # 5 emails/second default

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_import(mailbox_id, tenant_id, opts \\ []) do
    GenServer.cast(__MODULE__, {:start_import, mailbox_id, tenant_id, opts})
  end

  @impl true
  def init(_opts) do
    {:ok, %{active: %{}}}
  end

  @impl true
  def handle_cast({:start_import, mailbox_id, tenant_id, opts}, state) do
    if Map.has_key?(state.active, mailbox_id) do
      {:noreply, state}
    else
      task = Task.async(fn -> run_import(mailbox_id, tenant_id, opts) end)
      {:noreply, put_in(state, [:active, mailbox_id], task)}
    end
  end

  @impl true
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    active = Enum.reject(state.active, fn {_, task} -> task.ref == ref end) |> Map.new()
    {:noreply, %{state | active: active}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp run_import(mailbox_id, tenant_id, opts) do
    mailbox = Kontor.Repo.get(Kontor.Accounts.Mailbox, mailbox_id)
    months = Keyword.get(opts, :months, mailbox.task_age_cutoff_months || 3)
    cutoff = DateTime.add(DateTime.utc_now(), -months * 30 * 86_400)

    Logger.info("Starting import for mailbox #{mailbox_id}, cutoff: #{cutoff}")

    folders = case Kontor.MCP.HimalayaClient.list_folders(mailbox.himalaya_config) do
      {:ok, f} -> f
      _ -> ["INBOX"]
    end

    total = length(folders) * 100
    processed = 0

    Enum.reduce(folders, processed, fn folder, count ->
      import_folder(mailbox, folder, cutoff, tenant_id, count, total)
    end)

    Logger.info("Import complete for mailbox #{mailbox_id}")
  end

  defp import_folder(mailbox, folder, cutoff, tenant_id, count, total) do
    case Kontor.MCP.HimalayaClient.list_emails(mailbox.himalaya_config, folder, 200) do
      {:ok, emails} ->
        emails
        |> Enum.filter(fn e -> parse_dt(e["date"]) >= cutoff end)
        |> Enum.with_index(count + 1)
        |> Enum.reduce(count, fn {email, idx}, acc ->
          import_email(email, mailbox, tenant_id)
          broadcast_progress(tenant_id, idx, total)
          :timer.sleep(@rate_limit_ms)
          acc + 1
        end)
      _ -> count
    end
  end

  defp import_email(raw_email, mailbox, tenant_id) do
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

    Kontor.Repo.insert(
      Kontor.Mail.Email.changeset(%Kontor.Mail.Email{}, attrs),
      on_conflict: :nothing,
      conflict_target: [:tenant_id, :message_id]
    )
  end

  defp broadcast_progress(tenant_id, current, total) do
    Phoenix.PubSub.broadcast(
      Kontor.PubSub,
      "notifications:#{tenant_id}",
      {:import_progress, %{current: current, total: total}}
    )
  end

  defp parse_dt(nil), do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp parse_dt(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end
end
