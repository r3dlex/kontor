defmodule Kontor.Calendar do
  @moduledoc "Context module for calendar events and briefings."

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.Calendar.CalendarEvent

  def list_today_events(tenant_id) do
    today_start = DateTime.utc_now() |> DateTime.truncate(:second) |> beginning_of_day()
    today_end = DateTime.add(today_start, 86_399)

    Repo.all(
      from e in CalendarEvent,
      where: e.tenant_id == ^tenant_id
        and e.start_time >= ^today_start
        and e.start_time <= ^today_end,
      order_by: [asc: :start_time]
    )
  end

  def get_event(id, tenant_id) do
    case Repo.get_by(CalendarEvent, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      event -> {:ok, event}
    end
  end

  def get_event_by_external(provider, external_id, tenant_id) do
    Repo.get_by(CalendarEvent, provider: provider, external_id: external_id, tenant_id: tenant_id)
  end

  def upsert_event(attrs, tenant_id) do
    attrs = Map.put(attrs, :tenant_id, tenant_id)

    case get_event_by_external(attrs[:provider], attrs[:external_id], tenant_id) do
      nil ->
        %CalendarEvent{} |> CalendarEvent.changeset(attrs) |> Repo.insert()
      event ->
        event |> CalendarEvent.changeset(attrs) |> Repo.update()
    end
  end

  def update_briefing(id, markdown, tenant_id) do
    with {:ok, event} <- get_event(id, tenant_id) do
      event
      |> CalendarEvent.changeset(%{
        briefing_markdown: markdown,
        briefing_generated_at: DateTime.utc_now()
      })
      |> Repo.update()
    end
  end

  def create_event(attrs, tenant_id) do
    %CalendarEvent{}
    |> CalendarEvent.changeset(Map.put(attrs, :tenant_id, tenant_id))
    |> Repo.insert()
  end

  def update_event(%{id: id} = attrs, tenant_id) do
    with {:ok, event} <- get_event(id, tenant_id) do
      event |> CalendarEvent.changeset(Map.delete(attrs, :id)) |> Repo.update()
    end
  end

  def events_needing_briefing(tenant_id) do
    today_start = DateTime.utc_now() |> DateTime.truncate(:second) |> beginning_of_day()
    today_end = DateTime.add(today_start, 86_399)

    Repo.all(
      from e in CalendarEvent,
      where: e.tenant_id == ^tenant_id
        and e.start_time >= ^today_start
        and e.start_time <= ^today_end
        and is_nil(e.briefing_generated_at),
      order_by: [asc: :start_time]
    )
  end

  def regenerate_briefing(event_id, tenant_id) do
    with {:ok, event} <- get_event(event_id, tenant_id) do
      skill_input = %{
        title: event.title,
        attendees: event.attendees,
        start_time: event.start_time,
        location: event.location
      }
      case Kontor.AI.Pipeline.run_skill("briefing_generator", skill_input, tenant_id) do
        {:ok, result} ->
          markdown = Map.get(result, "briefing_markdown", "## Briefing\n\nGenerated briefing.")
          update_briefing(event_id, markdown, tenant_id)
        {:error, _} ->
          update_briefing(event_id, "## Briefing\n\nUnable to generate briefing.", tenant_id)
      end
    end
  end

  defp beginning_of_day(%DateTime{} = dt) do
    %{dt | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end
end
