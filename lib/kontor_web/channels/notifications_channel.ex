defmodule KontorWeb.NotificationsChannel do
  use KontorWeb, :channel

  @impl true
  def join("notifications:" <> user_id, _params, socket) do
    if socket.assigns.user_id == user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @doc "Push import progress notification to the user."
  def push_import_progress(user_id, %{processed: processed, total: total}) do
    Phoenix.PubSub.broadcast(Kontor.PubSub, "notifications:#{user_id}", {
      :import_progress,
      %{processed: processed, total: total}
    })
  end

  @impl true
  def handle_info({:import_progress, payload}, socket) do
    push(socket, "import_progress", payload)
    {:noreply, socket}
  end

  def handle_info({:new_task, task}, socket) do
    push(socket, "new_task", %{task_id: task.id, title: task.title})
    {:noreply, socket}
  end

  def handle_info({:calendar_update, event}, socket) do
    push(socket, "calendar_update", %{event_id: event.id})
    {:noreply, socket}
  end
end
