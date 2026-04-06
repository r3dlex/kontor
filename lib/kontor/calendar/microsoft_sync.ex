defmodule Kontor.Calendar.MicrosoftSync do
  @moduledoc "Polls Microsoft Graph API for calendar events."
  use GenServer
  require Logger

  @poll_interval_ms 5 * 60 * 1_000
  @graph_base "https://graph.microsoft.com/v1.0"

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
    with {:ok, token} <- Kontor.Auth.get_microsoft_token(tenant_id),
         {:ok, events} <- fetch_today_events(token) do
      Enum.each(events, fn event ->
        attrs = %{
          provider: :microsoft,
          external_id: event["id"],
          title: event["subject"] || "(No Title)",
          attendees: extract_attendees(event),
          start_time: parse_datetime(get_in(event, ["start", "dateTime"])),
          end_time: parse_datetime(get_in(event, ["end", "dateTime"])),
          location: get_in(event, ["location", "displayName"])
        }
        Kontor.Calendar.upsert_event(attrs, tenant_id)
      end)
    else
      {:error, reason} ->
        Logger.warning("MicrosoftSync failed for tenant #{tenant_id}: #{inspect(reason)}")
    end
  end

  defp fetch_today_events(token) do
    today = Date.utc_today()
    start_dt = DateTime.new!(today, ~T[00:00:00], "Etc/UTC") |> DateTime.to_iso8601()
    end_dt = DateTime.new!(today, ~T[23:59:59], "Etc/UTC") |> DateTime.to_iso8601()

    url = "#{@graph_base}/me/calendarView?startDateTime=#{start_dt}&endDateTime=#{end_dt}"

    case Req.get(url, headers: [{"Authorization", "Bearer #{token}"}]) do
      {:ok, %{status: 200, body: %{"value" => events}}} -> {:ok, events}
      {:ok, %{status: status}} -> {:error, {:http, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_attendees(%{"attendees" => attendees}) when is_list(attendees) do
    Enum.map(attendees, &get_in(&1, ["emailAddress", "address"]))
  end
  defp extract_attendees(_), do: []

  defp parse_datetime(nil), do: nil
  defp parse_datetime(str) do
    case DateTime.from_iso8601(str <> "Z") do
      {:ok, dt, _} -> dt
      _ ->
        case DateTime.from_iso8601(str) do
          {:ok, dt, _} -> dt
          _ -> nil
        end
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end
end
