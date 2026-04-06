defmodule Kontor.MCP.AsanaClient do
  @moduledoc "MCP client for Asana task synchronization."
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def create_task(task, project_gid) do
    GenServer.call(__MODULE__, {:create_task, task, project_gid}, 30_000)
  end

  def update_task(asana_gid, attrs) do
    GenServer.call(__MODULE__, {:update_task, asana_gid, attrs}, 30_000)
  end

  def get_task(asana_gid) do
    GenServer.call(__MODULE__, {:get_task, asana_gid}, 30_000)
  end

  def find_or_create_project(tenant_id, tenant_name) do
    GenServer.call(__MODULE__, {:find_or_create_project, tenant_id, tenant_name}, 30_000)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_task, task, project_gid}, _from, state) do
    result = mcp_call("asana/create_task", %{
      name: task.title,
      notes: task.description,
      projects: [project_gid],
      due_on: format_date(task.scheduled_action_at)
    })
    {:reply, result, state}
  end

  @impl true
  def handle_call({:update_task, asana_gid, attrs}, _from, state) do
    result = mcp_call("asana/update_task", Map.put(attrs, :task_gid, asana_gid))
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_task, asana_gid}, _from, state) do
    result = mcp_call("asana/get_task", %{task_gid: asana_gid})
    {:reply, result, state}
  end

  @impl true
  def handle_call({:find_or_create_project, tenant_id, tenant_name}, _from, state) do
    project_name = "#{tenant_name} [#{tenant_id}]"
    result = mcp_call("asana/find_or_create_project", %{name: project_name})
    {:reply, result, state}
  end

  defp mcp_call(method, params) do
    base_url = Application.get_env(:kontor, :asana_mcp_url, "http://localhost:8081")
    url = "#{base_url}/mcp/call"

    case Req.post(url, json: %{method: method, params: params}) do
      {:ok, %{status: 200, body: %{"result" => result}}} -> {:ok, result}
      {:ok, %{status: _, body: %{"error" => err}}} -> {:error, err}
      {:error, reason} -> {:error, reason}
    end
  end

  defp format_date(nil), do: nil
  defp format_date(%DateTime{} = dt), do: DateTime.to_date(dt) |> Date.to_iso8601()
end
