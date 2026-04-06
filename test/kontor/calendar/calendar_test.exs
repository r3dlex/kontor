defmodule Kontor.CalendarTest do
  use Kontor.DataCase, async: true

  alias Kontor.Calendar

  @tenant "tenant-calendar-test"

  defp today_noon do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    %{now | hour: 12, minute: 0, second: 0, microsecond: {0, 0}}
  end

  defp yesterday_noon do
    DateTime.add(today_noon(), -86_400)
  end

  defp tomorrow_noon do
    DateTime.add(today_noon(), 86_400)
  end

  # ---------------------------------------------------------------------------
  # list_today_events/1
  # ---------------------------------------------------------------------------

  describe "list_today_events/1" do
    test "returns events scheduled for today ordered by start_time ascending" do
      t1 = %{today_noon() | hour: 9}
      t2 = %{today_noon() | hour: 14}

      insert(:calendar_event, tenant_id: @tenant, external_id: "evt-1",
             start_time: t2, end_time: DateTime.add(t2, 3600))
      insert(:calendar_event, tenant_id: @tenant, external_id: "evt-2",
             start_time: t1, end_time: DateTime.add(t1, 3600))

      events = Calendar.list_today_events(@tenant)

      assert length(events) == 2
      start_times = Enum.map(events, & &1.start_time)
      assert start_times == Enum.sort(start_times, DateTime)
    end

    test "returns empty list when no events today" do
      assert Calendar.list_today_events(@tenant) == []
    end

    test "does not return events from yesterday" do
      yd = yesterday_noon()
      insert(:calendar_event, tenant_id: @tenant, external_id: "evt-yd",
             start_time: yd, end_time: DateTime.add(yd, 3600))

      assert Calendar.list_today_events(@tenant) == []
    end

    test "does not return events from tomorrow" do
      tm = tomorrow_noon()
      insert(:calendar_event, tenant_id: @tenant, external_id: "evt-tm",
             start_time: tm, end_time: DateTime.add(tm, 3600))

      assert Calendar.list_today_events(@tenant) == []
    end

    test "does not return events for other tenants" do
      t = today_noon()
      insert(:calendar_event, tenant_id: "other-tenant", external_id: "evt-other",
             start_time: t, end_time: DateTime.add(t, 3600))

      assert Calendar.list_today_events(@tenant) == []
    end
  end

  # ---------------------------------------------------------------------------
  # get_event/2
  # ---------------------------------------------------------------------------

  describe "get_event/2" do
    test "returns {:ok, event} when found for tenant" do
      event = insert(:calendar_event, tenant_id: @tenant)

      assert {:ok, found} = Calendar.get_event(event.id, @tenant)
      assert found.id == event.id
    end

    test "returns {:error, :not_found} when event id does not exist" do
      assert {:error, :not_found} = Calendar.get_event(Ecto.UUID.generate(), @tenant)
    end

    test "returns {:error, :not_found} when event belongs to different tenant" do
      event = insert(:calendar_event, tenant_id: "other-tenant", external_id: "other-ext")

      assert {:error, :not_found} = Calendar.get_event(event.id, @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # upsert_event/2
  # ---------------------------------------------------------------------------

  describe "upsert_event/2 — insert path" do
    test "inserts a new event when external_id does not exist" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      attrs = %{
        provider: :google,
        external_id: "gcal-new-001",
        title: "Kickoff Meeting",
        start_time: now,
        end_time: DateTime.add(now, 3600),
        attendees: ["alice@e.com"]
      }

      assert {:ok, event} = Calendar.upsert_event(attrs, @tenant)
      assert event.external_id == "gcal-new-001"
      assert event.title == "Kickoff Meeting"
      assert event.tenant_id == @tenant
    end

    test "inserts event with same external_id for different tenant" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      attrs = %{
        provider: :google, external_id: "shared-ext",
        title: "My Event", start_time: now, end_time: DateTime.add(now, 3600)
      }
      insert(:calendar_event, tenant_id: "other-tenant", external_id: "shared-ext")

      assert {:ok, event} = Calendar.upsert_event(attrs, @tenant)
      assert event.tenant_id == @tenant
    end
  end

  describe "upsert_event/2 — update path" do
    test "updates existing event when provider + external_id match" do
      existing = insert(:calendar_event, tenant_id: @tenant,
                        provider: :google, external_id: "gcal-update-001",
                        title: "Old Title")
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      attrs = %{
        provider: :google, external_id: "gcal-update-001",
        title: "New Title", start_time: now, end_time: DateTime.add(now, 3600)
      }

      assert {:ok, updated} = Calendar.upsert_event(attrs, @tenant)
      assert updated.id == existing.id
      assert updated.title == "New Title"
    end
  end

  # ---------------------------------------------------------------------------
  # update_briefing/3
  # ---------------------------------------------------------------------------

  describe "update_briefing/3" do
    test "sets briefing_markdown and briefing_generated_at on event" do
      event = insert(:calendar_event, tenant_id: @tenant)
      markdown = "# Meeting Brief\n\nAttendees: Alice, Bob"

      assert {:ok, updated} = Calendar.update_briefing(event.id, markdown, @tenant)
      assert updated.briefing_markdown == markdown
      assert updated.briefing_generated_at != nil
    end

    test "sets briefing_generated_at to a recent timestamp" do
      before = DateTime.utc_now() |> DateTime.truncate(:second)
      event = insert(:calendar_event, tenant_id: @tenant)

      {:ok, updated} = Calendar.update_briefing(event.id, "Brief", @tenant)

      assert DateTime.compare(updated.briefing_generated_at, before) in [:gt, :eq]
    end

    test "returns {:error, :not_found} when event does not exist" do
      assert {:error, :not_found} = Calendar.update_briefing(Ecto.UUID.generate(), "Brief", @tenant)
    end

    test "returns {:error, :not_found} when event belongs to different tenant" do
      event = insert(:calendar_event, tenant_id: "other-tenant", external_id: "other-ext-brief")

      assert {:error, :not_found} = Calendar.update_briefing(event.id, "Brief", @tenant)
    end

    test "can update briefing multiple times on the same event" do
      event = insert(:calendar_event, tenant_id: @tenant)

      {:ok, first} = Calendar.update_briefing(event.id, "First brief", @tenant)
      {:ok, second} = Calendar.update_briefing(event.id, "Updated brief", @tenant)

      assert second.briefing_markdown == "Updated brief"
      assert DateTime.compare(second.briefing_generated_at, first.briefing_generated_at) in [:gt, :eq]
    end
  end
end
