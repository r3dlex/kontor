defmodule KontorWeb.API.V1.ContactController do
  use KontorWeb, :controller

  alias Kontor.Contacts

  def index(conn, params) do
    tenant_id = conn.assigns.tenant_id
    opts = [
      mailbox_id: params["mailbox_id"],
      organization: params["organization"],
      limit: String.to_integer(params["limit"] || "50"),
      offset: String.to_integer(params["offset"] || "0")
    ]

    contacts = Contacts.list_contacts(tenant_id, opts)
    json(conn, %{contacts: Enum.map(contacts, &contact_json/1)})
  end

  def show(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id

    case Contacts.get_contact(id, tenant_id) do
      {:ok, contact} -> json(conn, %{contact: contact_json(contact)})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
    end
  end

  def graph(conn, _params) do
    tenant_id = conn.assigns.tenant_id
    graph_data = Contacts.graph_data(tenant_id)
    json(conn, graph_data)
  end

  def refresh(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id

    case Contacts.resynthesize_profile(id, tenant_id) do
      {:ok, contact} -> json(conn, %{contact: contact_json(contact)})
      {:error, reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  defp contact_json(c) do
    %{
      id: c.id,
      email_address: c.email_address,
      display_name: c.display_name,
      organization: c.organization,
      role: c.role,
      importance_weight: c.importance_weight,
      profile_markdown: c.profile_markdown,
      first_seen: c.first_seen,
      last_seen: c.last_seen
    }
  end
end
