defmodule Kontor.Tasks do
  @moduledoc "Context module for task management and Asana sync."

  import Ecto.Query
  require Logger
  alias Kontor.Repo
  alias Kontor.Tasks.Task

  def list_tasks(tenant_id, opts \\ []) do
    query = from t in Task,
      where: t.tenant_id == ^tenant_id,
      order_by: [desc: :importance]

    query
    |> maybe_filter_status(opts[:status])
    |> Repo.all()
  end

  def get_task(id, tenant_id) do
    Repo.get_by(Task, id: id, tenant_id: tenant_id)
  end

  def create_task(attrs, tenant_id) do
    attrs = atomize(attrs) |> Map.put(:tenant_id, tenant_id)

    result =
      %Task{}
      |> Task.changeset(attrs)
      |> maybe_auto_confirm()
      |> Repo.insert()

    with {:ok, task} <- result do
      broadcast_task_created(task)
      maybe_log_low_confidence(task)
      maybe_sync_asana(task)
      {:ok, task}
    end
  end

  def update_task(id, attrs, tenant_id) do
    case get_task(id, tenant_id) do
      nil -> {:error, :not_found}
      task ->
        result = task |> Task.changeset(atomize(attrs)) |> Repo.update()

        with {:ok, updated} <- result do
          broadcast_task_updated(updated)
          maybe_sync_asana(updated)
          {:ok, updated}
        end
    end
  end

  def delete_task(id, tenant_id) do
    case get_task(id, tenant_id) do
      nil -> {:error, :not_found}
      task ->
        result = Repo.delete(task)
        with {:ok, deleted} <- result do
          broadcast_task_deleted(deleted)
          {:ok, deleted}
        end
    end
  end

  defp maybe_auto_confirm(%Ecto.Changeset{} = cs) do
    confidence = Ecto.Changeset.get_field(cs, :confidence) || 0.0
    threshold = Application.get_env(:kontor, :tasks)[:auto_confirm_threshold_high]

    if confidence >= threshold do
      Ecto.Changeset.put_change(cs, :status, :confirmed)
    else
      cs
    end
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status) do
    where(query, [t], t.status == ^String.to_existing_atom(status))
  end

  defp broadcast_task_created(task) do
    Phoenix.PubSub.broadcast(Kontor.PubSub, "tasks:#{task.tenant_id}", {:task_created, task})
  end

  defp broadcast_task_updated(task) do
    Phoenix.PubSub.broadcast(Kontor.PubSub, "tasks:#{task.tenant_id}", {:task_updated, task})
  end

  defp broadcast_task_deleted(task) do
    Phoenix.PubSub.broadcast(Kontor.PubSub, "tasks:#{task.tenant_id}", {:task_deleted, task})
  end

  defp maybe_log_low_confidence(%Task{confidence: c, id: id}) do
    threshold_low = Application.get_env(:kontor, :tasks)[:auto_confirm_threshold_low]
    if c < threshold_low do
      Logger.debug("Task #{id} has low confidence (#{c}) — logged only, no user action required")
    end
  end

  defp maybe_sync_asana(%Task{status: :confirmed, confidence: c} = task) do
    threshold = Application.get_env(:kontor, :tasks)[:auto_confirm_threshold_high]
    if c >= threshold, do: Kontor.Tasks.AsanaSyncWorker.enqueue(task)
  end
  defp maybe_sync_asana(_task), do: :ok

  defp atomize(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    _ -> attrs
  end
end
