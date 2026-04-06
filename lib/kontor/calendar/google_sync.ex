defmodule Kontor.Calendar.GoogleSync do
  @moduledoc "Polls Google Calendar MCP for events and upserts into local DB."
  use GenServer
  require Logger

  @poll_interval_ms 5 * 60 * 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_poll()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    poll_all_tenants()
    schedule_poll()
    {:noreply, state}
  end

  defp poll_all_tenants do
    tenant_ids = Kontor.Accounts.list_tenant_ids()
    Enum.each(tenant_ids, &sync_tenant/1)
  end

  defp sync_tenant(tenant_id) do
    case Kontor.MCP.GoogleCalendarClient.list_today_events(tenant_id) do
      {:ok, events} ->
        Enum.each(events, fn event ->
          attrs = %{
            provider: :google,
            external_id: event["id"],
            title: event["summary"] || "(No Title)",
            attendees: extract_attendees(event),
            start_time: parse_datetime(get_in(event, ["start", "dateTime"])),
            end_time: parse_datetime(get_in(event, ["end", "dateTime"])),
            location: event["location"]
          }
          Kontor.Calendar.upsert_event(attrs, tenant_id)
        end)
      {:error, reason} ->
        Logger.warning("GoogleSync failed for tenant #{tenant_id}: #{inspect(reason)}")
    end
  end

  defp extract_attendees(%{"attendees" => attendees}) when is_list(attendees) do
    Enum.map(attendees, & &1["email"])
  end
  defp extract_attendees(_), do: []

  defp parse_datetime(nil), do: nil
  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end
end
