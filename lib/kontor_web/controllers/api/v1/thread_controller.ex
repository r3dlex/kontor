defmodule KontorWeb.API.V1.ThreadController do
  use KontorWeb, :controller

  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id

    case Kontor.Mail.get_thread(id, tenant_id) do
      {:ok, thread} ->
        json(conn, %{thread: thread_json(thread)})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})
    end
  end

  def update(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant_id
    attrs = Map.take(params, ["markdown_content", "score_urgency", "score_action", "score_authority", "score_momentum"])

    case Kontor.Mail.get_thread(id, tenant_id) do
      {:ok, thread} ->
        case Kontor.Mail.update_thread(thread, attrs, tenant_id) do
          {:ok, updated} -> json(conn, %{thread: thread_json(updated)})
          {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
        end
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})
    end
  end

  defp thread_json(thread) do
    %{
      id: thread.id,
      thread_id: thread.thread_id,
      markdown_content: thread.markdown_content,
      composite_score: thread.composite_score,
      score_urgency: thread.score_urgency,
      score_action: thread.score_action,
      score_authority: thread.score_authority,
      score_momentum: thread.score_momentum,
      last_updated: thread.last_updated
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
