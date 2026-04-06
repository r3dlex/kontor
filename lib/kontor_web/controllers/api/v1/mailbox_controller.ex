defmodule KontorWeb.API.V1.MailboxController do
  use KontorWeb, :controller

  alias Kontor.Accounts

  def index(conn, _params) do
    mailboxes = Accounts.list_mailboxes(conn.assigns.tenant_id)
    json(conn, %{mailboxes: Enum.map(mailboxes, &mailbox_json/1)})
  end

  def create(conn, params) do
    case Accounts.create_mailbox(params, conn.assigns.tenant_id) do
      {:ok, mb} -> conn |> put_status(:created) |> json(%{mailbox: mailbox_json(mb)})
      {:error, %Ecto.Changeset{} = cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: %{}})
    end
  end

  def show(conn, %{"id" => id}) do
    case Accounts.get_mailbox(id, conn.assigns.tenant_id) do
      {:ok, mb} -> json(conn, %{mailbox: mailbox_json(mb)})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, mb} <- Accounts.get_mailbox(id, conn.assigns.tenant_id),
         {:ok, updated} <- Accounts.update_mailbox(mb, params) do
      json(conn, %{mailbox: mailbox_json(updated)})
    else
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      {:error, %Ecto.Changeset{} = cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, mb} <- Accounts.get_mailbox(id, conn.assigns.tenant_id),
         {:ok, _} <- Accounts.delete_mailbox(mb) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
    end
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp mailbox_json(mb) do
    %{
      id: mb.id,
      provider: mb.provider,
      email_address: mb.email_address,
      polling_interval_seconds: mb.polling_interval_seconds,
      task_age_cutoff_months: mb.task_age_cutoff_months,
      read_only: mb.read_only
    }
  end
end
