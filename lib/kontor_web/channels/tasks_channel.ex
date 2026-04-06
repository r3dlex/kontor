defmodule KontorWeb.TasksChannel do
  use KontorWeb, :channel

  @impl true
  def join("tasks:" <> user_id, _params, socket) do
    if socket.assigns.user_id == user_id do
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Subscribe to real-time task updates for this tenant
    Phoenix.PubSub.subscribe(Kontor.PubSub, "tasks:#{socket.assigns.tenant_id}")
    {:noreply, socket}
  end

  def handle_info({:task_created, task}, socket) do
    push(socket, "task_created", serialize_task(task))
    {:noreply, socket}
  end

  def handle_info({:task_updated, task}, socket) do
    push(socket, "task_updated", serialize_task(task))
    {:noreply, socket}
  end

  defp serialize_task(task) do
    %{
      id: task.id,
      title: task.title,
      status: task.status,
      task_type: task.task_type,
      importance: task.importance,
      confidence: task.confidence
    }
  end
end
