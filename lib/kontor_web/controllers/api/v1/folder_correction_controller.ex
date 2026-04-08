defmodule KontorWeb.API.V1.FolderCorrectionController do
  use KontorWeb, :controller

  alias Kontor.Mail

  def create(conn, %{"mailbox_id" => mailbox_id} = params) do
    tenant_id = conn.assigns.tenant_id

    attrs = %{
      mailbox_id: mailbox_id,
      email_id: params["email_id"],
      from_folder: params["from_folder"],
      to_folder: params["to_folder"],
      sender: params["sender"],
      sender_domain: params["sender_domain"]
    }

    case Mail.record_folder_correction(attrs, tenant_id) do
      {:ok, correction} ->
        conn
        |> put_status(:created)
        |> json(%{data: %{id: correction.id, recorded_at: correction.recorded_at}})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
