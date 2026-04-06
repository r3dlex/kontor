defmodule Kontor.MCP.HimalayaClient do
  @moduledoc "MCP client for Himalaya email transport."
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  def list_emails(mailbox, folder \\ "INBOX", limit \\ 50) do
    call({:list_emails, mailbox, folder, limit})
  end

  def get_email(mailbox, message_id) do
    call({:get_email, mailbox, message_id})
  end

  def send_email(draft) do
    call({:send_email, draft})
  end

  def move_email(mailbox, message_id, folder) do
    call({:move_email, mailbox, message_id, folder})
  end

  def create_folder(mailbox, folder_name) do
    call({:create_folder, mailbox, folder_name})
  end

  def list_folders(mailbox) do
    call({:list_folders, mailbox})
  end

  # GenServer implementation

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:list_emails, mailbox, folder, limit}, _from, state) do
    result = mcp_call("himalaya/list_emails", %{
      mailbox: mailbox,
      folder: folder,
      limit: limit
    })
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_email, mailbox, message_id}, _from, state) do
    result = mcp_call("himalaya/get_email", %{mailbox: mailbox, message_id: message_id})
    {:reply, result, state}
  end

  @impl true
  def handle_call({:send_email, draft}, _from, state) do
    result = mcp_call("himalaya/send_email", %{
      mailbox: draft.mailbox_id,
      to: draft.recipients,
      subject: draft.subject,
      body: draft.draft_content
    })
    {:reply, result, state}
  end

  @impl true
  def handle_call({:move_email, mailbox, message_id, folder}, _from, state) do
    result = mcp_call("himalaya/move_email", %{
      mailbox: mailbox,
      message_id: message_id,
      folder: folder
    })
    {:reply, result, state}
  end

  @impl true
  def handle_call({:create_folder, mailbox, folder_name}, _from, state) do
    result = mcp_call("himalaya/create_folder", %{mailbox: mailbox, folder: folder_name})
    {:reply, result, state}
  end

  @impl true
  def handle_call({:list_folders, mailbox}, _from, state) do
    result = mcp_call("himalaya/list_folders", %{mailbox: mailbox})
    {:reply, result, state}
  end

  defp call(request) do
    GenServer.call(__MODULE__, request, 30_000)
  end

  defp mcp_call(method, params) do
    base_url = Application.get_env(:kontor, :himalaya_mcp_url, "http://localhost:8080")
    url = "#{base_url}/mcp/call"

    case Req.post(url, json: %{method: method, params: params}) do
      {:ok, %{status: 200, body: %{"result" => result}}} -> {:ok, result}
      {:ok, %{status: _, body: %{"error" => err}}} -> {:error, err}
      {:error, reason} -> {:error, reason}
    end
  end
end
