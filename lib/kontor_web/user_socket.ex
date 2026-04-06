defmodule KontorWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", KontorWeb.ChatChannel
  channel "notifications:*", KontorWeb.NotificationsChannel
  channel "tasks:*", KontorWeb.TasksChannel
  channel "contacts:*", KontorWeb.ContactsChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case KontorWeb.Auth.verify_token(token) do
      {:ok, claims} ->
        {:ok,
         socket
         |> assign(:user_id, claims["sub"])
         |> assign(:tenant_id, claims["tenant_id"] || Kontor.tenant_id())}

      {:error, _} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
