defmodule KontorWeb.ContactsChannel do
  use KontorWeb, :channel

  @impl true
  def join("contacts:" <> user_id, _params, socket) do
    if socket.assigns.user_id == user_id do
      Phoenix.PubSub.subscribe(Kontor.PubSub, "contacts:#{socket.assigns.tenant_id}")
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info({:contact_updated, contact}, socket) do
    push(socket, "contact_updated", %{contact_id: contact.id})
    {:noreply, socket}
  end

  def handle_info({:graph_updated}, socket) do
    push(socket, "graph_updated", %{})
    {:noreply, socket}
  end
end
