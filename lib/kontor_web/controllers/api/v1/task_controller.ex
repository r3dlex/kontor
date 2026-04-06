defmodule KontorWeb.API.V1.TaskController do
  use KontorWeb, :controller

  alias Kontor.Tasks

  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id
    status = Map.get(params, "status")
    mailbox_id = Map.get(params, "mailbox_id")

    tasks = Tasks.list_tasks(tenant_id, status: status, mailbox_id: mailbox_id)
    json(conn, %{tasks: Enum.map(tasks, &task_json/1)})
  end

  def create(conn, params) do
    tenant_id = conn.assigns.tenant_id

    case Tasks.create_task(params, tenant_id) do
      {:ok, task} -> conn |> put_status(:created) |> json(%{task: task_json(task)})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  def delete(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    case Tasks.delete_task(id, tenant_id) do
      {:ok, _} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
    end
  end

  def update(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant_id

    case Tasks.update_task(id, params, tenant_id) do
      {:ok, task} -> json(conn, %{task: task_json(task)})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  defp task_json(task) do
    %{
      id: task.id,
      task_type: task.task_type,
      title: task.title,
      description: task.description,
      importance: task.importance,
      status: task.status,
      confidence: task.confidence,
      draft_content: task.draft_content,
      style_profile_used: task.style_profile_used,
      scheduled_action_at: task.scheduled_action_at,
      thread_id: task.thread_id,
      email_id: task.email_id,
      inserted_at: task.inserted_at
    }
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
