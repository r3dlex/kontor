defmodule Kontor.MCP.GoogleCalendarClient do
  @moduledoc "MCP client for Google Calendar."
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def list_today_events(tenant_id) do
    GenServer.call(__MODULE__, {:list_today_events, tenant_id}, 30_000)
  end

  def create_event(tenant_id, attrs) do
    GenServer.call(__MODULE__, {:create_event, tenant_id, attrs}, 30_000)
  end

  def update_event(tenant_id, event_id, attrs) do
    GenServer.call(__MODULE__, {:update_event, tenant_id, event_id, attrs}, 30_000)
  end

  def delete_event(tenant_id, event_id) do
    GenServer.call(__MODULE__, {:delete_event, tenant_id, event_id}, 30_000)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:list_today_events, tenant_id}, _from, state) do
    today = Date.utc_today() |> Date.to_iso8601()
    result = mcp_call("gcal/list_events", %{tenant_id: tenant_id, date: today})
    {:reply, result, state}
  end

  @impl true
  def handle_call({:create_event, tenant_id, attrs}, _from, state) do
    result = mcp_call("gcal/create_event", Map.put(attrs, :tenant_id, tenant_id))
    {:reply, result, state}
  end

  @impl true
  def handle_call({:update_event, tenant_id, event_id, attrs}, _from, state) do
    result = mcp_call("gcal/update_event", attrs |> Map.put(:tenant_id, tenant_id) |> Map.put(:event_id, event_id))
    {:reply, result, state}
  end

  @impl true
  def handle_call({:delete_event, tenant_id, event_id}, _from, state) do
    result = mcp_call("gcal/delete_event", %{tenant_id: tenant_id, event_id: event_id})
    {:reply, result, state}
  end

  defp mcp_call(method, params) do
    base_url = Application.get_env(:kontor, :google_calendar_mcp_url, "http://localhost:8082")
    url = "#{base_url}/mcp/call"

    case Req.post(url, json: %{method: method, params: params}) do
      {:ok, %{status: 200, body: %{"result" => result}}} -> {:ok, result}
      {:ok, %{status: _, body: %{"error" => err}}} -> {:error, err}
      {:error, reason} -> {:error, reason}
    end
  end
end
