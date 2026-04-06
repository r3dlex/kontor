defmodule KontorWeb.ChatChannel do
  use KontorWeb, :channel
  require Logger

  alias Kontor.Chat
  alias Kontor.AI.MinimaxClient

  @impl true
  def join("chat:" <> user_id, _params, socket) do
    if socket.assigns.user_id == user_id do
      Phoenix.PubSub.subscribe(Kontor.PubSub, "chat:#{user_id}")
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("user_message", %{"content" => content, "view_context" => ctx}, socket) do
    tenant_id = socket.assigns.tenant_id
    user_id = socket.assigns.user_id

    view = Map.get(ctx, "view", "unknown")
    {:ok, session} = Chat.get_or_create_session(user_id, view, tenant_id)

    {:ok, _} = Chat.save_message(
      %{session_id: session.id, user_id: user_id, role: :user, content: content, view_context: ctx},
      tenant_id
    )

    # Push typing indicator
    push(socket, "typing", %{})

    # Process async, broadcast back via PubSub
    topic = "chat:#{user_id}"
    Task.start(fn ->
      case process_chat(content, ctx, tenant_id) do
        {:ok, response} ->
          {:ok, _} = Chat.save_message(
            %{session_id: session.id, user_id: user_id, role: :assistant,
              content: response, view_context: ctx},
            tenant_id
          )
          Phoenix.PubSub.broadcast(Kontor.PubSub, topic, {:chat_response, response, session.id})

        {:error, reason} ->
          Logger.error("ChatChannel AI error: #{inspect(reason)}")
          Phoenix.PubSub.broadcast(Kontor.PubSub, topic, {:chat_error, "Failed to process message"})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_response, response, session_id}, socket) do
    push(socket, "new_message", %{
      role: "assistant",
      content: response,
      session_id: session_id
    })
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_error, message}, socket) do
    push(socket, "error", %{message: message})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp process_chat(content, ctx, tenant_id) do
    thread_markdown = load_thread_markdown(ctx, tenant_id)
    prompt = build_chat_prompt(content, ctx, thread_markdown)
    MinimaxClient.complete(prompt, tenant_id)
  end

  defp load_thread_markdown(%{"active_thread_id" => id}, tenant_id) when is_binary(id) do
    case Kontor.Mail.get_thread(id, tenant_id) do
      {:ok, thread} -> thread.markdown_content
      _ -> nil
    end
  end
  defp load_thread_markdown(_, _), do: nil

  defp build_chat_prompt(message, ctx, thread_markdown) do
    view = Map.get(ctx, "view", "unknown")
    available_actions = Map.get(ctx, "available_actions", [])

    thread_section =
      if thread_markdown,
        do: "## Current Thread Context\n#{thread_markdown}\n\n",
        else: ""

    """
    You are Kontor, an AI email assistant. The user is currently in the #{view} view.

    #{thread_section}## Available Actions
    #{Enum.join(available_actions, ", ")}

    ## User Message
    #{message}

    Respond helpfully. If the user asks you to perform an action, return a JSON action object
    with the key "action" matching one of the available actions.
    """
  end
end
