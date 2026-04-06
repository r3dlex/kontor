defmodule Kontor.Contacts.OrganizationWorker do
  @moduledoc "Continuous + daily batch contact profile updates and importance scoring."
  use GenServer
  require Logger

  @daily_hour 6
  @batch_interval_ms 30_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def process_email_contacts(email, tenant_id) do
    GenServer.cast(__MODULE__, {:process_email, email, tenant_id})
  end

  @impl true
  def init(_opts) do
    schedule_daily()
    schedule_batch()
    {:ok, %{queue: []}}
  end

  @impl true
  def handle_cast({:process_email, email, tenant_id}, %{queue: queue} = state) do
    {:noreply, %{state | queue: [{email, tenant_id} | queue]}}
  end

  @impl true
  def handle_info(:process_batch, %{queue: queue} = state) do
    Enum.each(queue, fn {email, tenant_id} ->
      process_contacts_for_email(email, tenant_id)
    end)
    schedule_batch()
    {:noreply, %{state | queue: []}}
  end

  @impl true
  def handle_info(:daily_batch, state) do
    run_daily_batch()
    schedule_daily()
    {:noreply, state}
  end

  defp process_contacts_for_email(email, tenant_id) do
    participants = [email.sender | (email.recipients || [])]
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.each(participants, fn address ->
      case Kontor.Contacts.upsert_contact(address, %{last_seen: now}, tenant_id) do
        {:ok, contact} ->
          Kontor.Contacts.upsert_mailbox_context(
            contact.id, email.mailbox_id,
            %{last_interaction: now, interaction_frequency: (contact.importance_weight * 10 |> trunc()) + 1},
            tenant_id
          )
        _ -> :ok
      end
    end)
  end

  defp run_daily_batch do
    tenant_ids = Kontor.Accounts.list_tenant_ids()
    Enum.each(tenant_ids, fn tenant_id ->
      contacts = Kontor.Contacts.list_contacts(tenant_id)
      Enum.each(contacts, fn contact ->
        weight = compute_importance(contact, tenant_id)
        Kontor.Contacts.upsert_contact(contact.email_address, %{importance_weight: weight}, tenant_id)
      end)
    end)
  end

  defp compute_importance(contact, _tenant_id) do
    # Frequency-based heuristic; v2 will use full graph analysis
    base = contact.importance_weight || 0.0
    min(base + 0.01, 1.0)
  end

  defp schedule_batch do
    Process.send_after(self(), :process_batch, @batch_interval_ms)
  end

  defp schedule_daily do
    now = DateTime.utc_now()
    target = %{now | hour: @daily_hour, minute: 0, second: 0, microsecond: {0, 0}}

    target = if DateTime.compare(target, now) == :lt do
      DateTime.add(target, 86_400)
    else
      target
    end

    ms = DateTime.diff(target, now, :millisecond)
    Process.send_after(self(), :daily_batch, ms)
  end
end
