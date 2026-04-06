defmodule Kontor.Calendar.BriefingWorker do
  @moduledoc "Generates meeting briefings at 6 AM and on calendar changes."
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def refresh_briefing(event_id, tenant_id) do
    GenServer.cast(__MODULE__, {:refresh, event_id, tenant_id})
  end

  @impl true
  def init(_opts) do
    schedule_daily()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:daily_briefing, state) do
    generate_all_briefings()
    schedule_daily()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:refresh, event_id, tenant_id}, state) do
    generate_briefing(event_id, tenant_id)
    {:noreply, state}
  end

  defp generate_all_briefings do
    tenant_ids = Kontor.Accounts.list_tenant_ids()
    Enum.each(tenant_ids, fn tenant_id ->
      events = Kontor.Calendar.events_needing_briefing(tenant_id)
      Enum.each(events, fn event ->
        generate_briefing(event.id, tenant_id)
      end)
    end)
  end

  defp generate_briefing(event_id, tenant_id) do
    with {:ok, event} <- Kontor.Calendar.get_event(event_id, tenant_id) do
      prompt = build_briefing_prompt(event, tenant_id)
      case Kontor.AI.MinimaxClient.complete(prompt, tenant_id) do
        {:ok, result} ->
          markdown = extract_markdown(result)
          Kontor.Calendar.update_briefing(event_id, markdown, tenant_id)
        {:error, reason} ->
          Logger.warning("Briefing generation failed for event #{event_id}: #{inspect(reason)}")
      end
    end
  end

  defp extract_markdown(%{"briefing_markdown" => md}) when is_binary(md), do: md
  defp extract_markdown(%{"raw" => md}) when is_binary(md), do: md
  defp extract_markdown(%{"content" => md}) when is_binary(md), do: md
  defp extract_markdown(result) when is_map(result), do: Jason.encode!(result)
  defp extract_markdown(_), do: "Briefing generation failed."

  defp build_briefing_prompt(event, _tenant_id) do
    attendee_list = Enum.join(event.attendees || [], ", ")

    """
    You are a meeting briefing assistant. Generate a structured markdown briefing.

    Generate a meeting briefing for:
    Title: #{event.title}
    Time: #{event.start_time} - #{event.end_time}
    Attendees: #{attendee_list}
    Location: #{event.location || "Not specified"}

    Include: purpose, agenda items, recommended position, and related context.
    Format as markdown with clear sections.
    """
  end

  defp schedule_daily do
    now = DateTime.utc_now()
    target = %{now | hour: 6, minute: 0, second: 0, microsecond: {0, 0}}

    target = if DateTime.compare(target, now) == :lt do
      DateTime.add(target, 86_400)
    else
      target
    end

    ms = DateTime.diff(target, now, :millisecond)
    Process.send_after(self(), :daily_briefing, ms)
  end
end
