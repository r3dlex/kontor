defmodule KontorWeb.API.V1.DraftController do
  use KontorWeb, :controller

  alias Kontor.Mail

  def index(conn, _params) do
    tenant_id = conn.assigns.tenant_id
    drafts = Kontor.Mail.list_drafts(tenant_id)
    json(conn, %{drafts: Enum.map(drafts, &draft_json/1)})
  end

  def create(conn, params) do
    tenant_id = conn.assigns.tenant_id

    case Mail.create_draft(params, tenant_id) do
      {:ok, draft} ->
        conn |> put_status(:created) |> json(%{draft: %{id: draft.id, subject: draft.subject}})
      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: cs})
    end
  end

  def send_draft(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant_id
    scheduled_at = params["scheduled_at"]

    case Mail.send_or_schedule_draft(id, scheduled_at, tenant_id) do
      {:ok, :sent} -> json(conn, %{status: "sent"})
      {:ok, :scheduled} -> json(conn, %{status: "scheduled"})
      {:error, reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  defp draft_json(draft) do
    %{
      id: draft.id,
      subject: draft.subject,
      draft_content: draft.draft_content,
      recipients: draft.recipients,
      scheduled_at: draft.scheduled_at,
      status: draft.status,
      sent_at: draft.sent_at,
      inserted_at: draft.inserted_at
    }
  end
end
