defmodule KontorWeb.API.V1.EmailLabelController do
  use KontorWeb, :controller

  alias Kontor.Mail

  def show(conn, %{"email_id" => email_id}) do
    tenant_id = conn.assigns.tenant_id

    case Mail.get_email_labels(email_id, tenant_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Labels not found"})
      label ->
        conn
        |> json(%{data: %{
          id: label.id,
          email_id: label.email_id,
          labels: label.labels,
          priority_score: label.priority_score,
          has_actionable_task: label.has_actionable_task,
          task_summary: label.task_summary,
          task_deadline: label.task_deadline,
          ai_confidence: label.ai_confidence,
          ai_reasoning: label.ai_reasoning,
          inserted_at: label.inserted_at
        }})
    end
  end
end
