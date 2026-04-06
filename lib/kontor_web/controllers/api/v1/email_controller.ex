defmodule KontorWeb.API.V1.EmailController do
  use KontorWeb, :controller

  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id

    case Kontor.Mail.get_email(id, tenant_id) do
      {:ok, email} ->
        thread = case email.thread_id do
          nil -> nil
          tid -> Kontor.Mail.get_thread_by_thread_id(tid, tenant_id)
        end

        json(conn, %{
          email: %{
            id: email.id,
            message_id: email.message_id,
            thread_id: email.thread_id,
            subject: email.subject,
            sender: email.sender,
            recipients: email.recipients,
            received_at: email.received_at
          },
          thread_markdown: thread && thread.markdown_content
        })

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})
    end
  end
end
