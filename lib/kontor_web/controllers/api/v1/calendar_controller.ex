defmodule KontorWeb.API.V1.CalendarController do
  use KontorWeb, :controller

  alias Kontor.Calendar

  def today(conn, _params) do
    tenant_id = conn.assigns.tenant_id
    events = Calendar.list_today_events(tenant_id)
    json(conn, %{events: Enum.map(events, &event_json/1)})
  end

  def briefing(conn, %{"event_id" => id}) do
    tenant_id = conn.assigns.tenant_id

    case Calendar.get_event(id, tenant_id) do
      {:ok, event} -> json(conn, %{event: event_json(event)})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
    end
  end

  def refresh_briefing(conn, %{"event_id" => id}) do
    tenant_id = conn.assigns.tenant_id

    case Calendar.regenerate_briefing(id, tenant_id) do
      {:ok, event} -> json(conn, %{event: event_json(event)})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      {:error, reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  def create_event(conn, params) do
    tenant_id = conn.assigns.tenant_id
    case Kontor.Calendar.create_event(atomize(params), tenant_id) do
      {:ok, event} -> conn |> put_status(:created) |> json(%{event: event_json(event)})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  def update_event(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant_id
    attrs = params |> Map.drop(["id"]) |> atomize() |> Map.put(:id, id)
    case Kontor.Calendar.update_event(attrs, tenant_id) do
      {:ok, event} -> json(conn, %{event: event_json(event)})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  defp atomize(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp event_json(event) do
    %{
      id: event.id,
      provider: event.provider,
      external_id: event.external_id,
      title: event.title,
      attendees: event.attendees,
      start_time: event.start_time,
      end_time: event.end_time,
      location: event.location,
      briefing_markdown: event.briefing_markdown,
      briefing_generated_at: event.briefing_generated_at
    }
  end
end
