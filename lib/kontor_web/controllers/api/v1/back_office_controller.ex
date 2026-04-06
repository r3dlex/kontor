defmodule KontorWeb.API.V1.BackOfficeController do
  use KontorWeb, :controller

  def index(conn, _params) do
    tenant_id = conn.assigns.tenant_id
    events = Kontor.Calendar.list_today_events(tenant_id)

    json(conn, %{
      date: Date.utc_today(),
      meetings: Enum.map(events, fn event ->
        %{
          id: event.id,
          title: event.title,
          start_time: event.start_time,
          end_time: event.end_time,
          attendees: event.attendees,
          location: event.location,
          briefing_markdown: event.briefing_markdown,
          briefing_generated_at: event.briefing_generated_at
        }
      end)
    })
  end
end
