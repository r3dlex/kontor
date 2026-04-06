defmodule Kontor.Tasks.AsanaSyncWorker do
  @moduledoc "Syncs confirmed tasks to Asana and reconciles Asana state."
  use GenServer
  require Logger

  @reconcile_interval_ms 5 * 60 * 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def enqueue(task) do
    GenServer.cast(__MODULE__, {:sync_task, task})
  end

  @impl true
  def init(_opts) do
    schedule_reconcile()
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:sync_task, task}, state) do
    do_sync(task)
    {:noreply, state}
  end

  @impl true
  def handle_info(:reconcile, state) do
    reconcile_all()
    schedule_reconcile()
    {:noreply, state}
  end

  defp do_sync(task) do
    tenant_id = task.tenant_id

    with {:ok, user} <- get_tenant_user(tenant_id),
         {:ok, project_gid} <- ensure_project(tenant_id, user.name || tenant_id) do
      case task.asana_sync_id do
        nil ->
          case Kontor.MCP.AsanaClient.create_task(task, project_gid) do
            {:ok, %{"gid" => gid}} ->
              Kontor.Tasks.update_task(task.id, %{asana_sync_id: gid}, tenant_id)
            {:error, reason} ->
              Logger.warning("Asana create failed for task #{task.id}: #{inspect(reason)}")
          end

        gid ->
          status_map = %{
            confirmed: "active",
            in_progress: "active",
            done: "completed",
            dismissed: "abandoned"
          }
          Kontor.MCP.AsanaClient.update_task(gid, %{
            completed: task.status == :done,
            name: task.title
          })
      end
    end
  end

  defp reconcile_all do
    import Ecto.Query

    tasks_with_asana =
      Kontor.Repo.all(
        from t in Kontor.Tasks.Task,
        where: not is_nil(t.asana_sync_id) and t.status not in [:done, :dismissed]
      )

    Enum.each(tasks_with_asana, fn task ->
      case Kontor.MCP.AsanaClient.get_task(task.asana_sync_id) do
        {:ok, %{"completed" => true}} ->
          Kontor.Tasks.update_task(task.id, %{status: :done}, task.tenant_id)
        {:ok, %{"resource_subtype" => "default_task", "memberships" => []}} ->
          # Removed from Asana - mark dismissed locally
          Kontor.Tasks.update_task(task.id, %{status: :dismissed}, task.tenant_id)
        _ ->
          :ok
      end
    end)
  end

  defp get_tenant_user(tenant_id) do
    case Kontor.Repo.get_by(Kontor.Accounts.User, tenant_id: tenant_id) do
      nil -> {:error, :no_user}
      user -> {:ok, user}
    end
  end

  defp ensure_project(tenant_id, tenant_name) do
    Kontor.MCP.AsanaClient.find_or_create_project(tenant_id, tenant_name)
  end

  defp schedule_reconcile do
    Process.send_after(self(), :reconcile, @reconcile_interval_ms)
  end
end
