defmodule Kontor.AI.Sandbox do
  @moduledoc """
  Allowlist GenServer that validates every LLM-proposed action before execution.
  The LLM never accesses the network directly. All proposed actions pass through here.

  Permitted actions: read_email, write_thread_markdown, update_score, draft_reply,
  create_calendar_entry, update_calendar_entry, manage_skill, create_task, update_task,
  manage_folder.
  """

  use GenServer
  require Logger

  @allowed_actions MapSet.new([
    :read_email,
    :write_thread_markdown,
    :update_score,
    :draft_reply,
    :create_calendar_entry,
    :update_calendar_entry,
    :manage_skill,
    :create_task,
    :update_task,
    :manage_folder
  ])

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Validates and executes an LLM-proposed action.
  Returns {:ok, result} or {:error, :not_permitted} | {:error, reason}.

  The view_context comes from the Vue frontend's viewport context payload,
  which declares available_actions per view.
  """
  def execute(action, params, tenant_id, view_context \\ %{}) do
    GenServer.call(__MODULE__, {:execute, action, params, tenant_id, view_context})
  end

  @doc "Returns the list of permitted action types."
  def allowed_actions, do: @allowed_actions

  @impl true
  def init(_opts) do
    {:ok, %{execution_log: []}}
  end

  @impl true
  def handle_call({:execute, action, params, tenant_id, view_context}, _from, state) do
    with :ok <- validate_action_type(action),
         :ok <- validate_tenant_scope(params, tenant_id),
         :ok <- validate_view_permissions(action, view_context) do
      result = do_execute(action, params, tenant_id)
      new_state = log_execution(state, action, params, tenant_id, result)
      {:reply, result, new_state}
    else
      {:error, reason} = error ->
        Logger.warning("AI Sandbox blocked action #{action}: #{reason}")
        {:reply, error, state}
    end
  end

  defp validate_action_type(action) do
    if MapSet.member?(@allowed_actions, action) do
      :ok
    else
      {:error, :not_permitted}
    end
  end

  defp validate_tenant_scope(params, tenant_id) do
    # Ensure any tenant_id in params matches the current tenant
    case Map.get(params, :tenant_id) do
      nil -> :ok
      ^tenant_id -> :ok
      _ -> {:error, :tenant_mismatch}
    end
  end

  defp validate_view_permissions(action, view_context) do
    available = Map.get(view_context, "available_actions", [])
    action_str = to_string(action)

    # If no view context provided, allow (server-side calls)
    if Enum.empty?(available) or action_str in available do
      :ok
    else
      {:error, :not_available_in_view}
    end
  end

  defp do_execute(:read_email, %{email_id: id}, tenant_id) do
    Kontor.Mail.get_email(id, tenant_id)
  end

  defp do_execute(:write_thread_markdown, %{thread_id: id, content: content}, tenant_id) do
    Kontor.Mail.update_thread_markdown(id, content, tenant_id)
  end

  defp do_execute(:update_score, %{thread_id: id} = scores, tenant_id) do
    Kontor.Mail.update_thread_scores(id, scores, tenant_id)
  end

  defp do_execute(:draft_reply, params, tenant_id) do
    Kontor.Mail.create_draft(params, tenant_id)
  end

  defp do_execute(:create_task, params, tenant_id) do
    Kontor.Tasks.create_task(params, tenant_id)
  end

  defp do_execute(:update_task, %{task_id: id} = params, tenant_id) do
    Kontor.Tasks.update_task(id, params, tenant_id)
  end

  defp do_execute(:manage_skill, params, tenant_id) do
    Kontor.AI.Skills.manage(params, tenant_id)
  end

  defp do_execute(:create_calendar_entry, params, tenant_id) do
    Kontor.Calendar.create_event(params, tenant_id)
  end

  defp do_execute(:update_calendar_entry, params, tenant_id) do
    Kontor.Calendar.update_event(params, tenant_id)
  end

  defp do_execute(:manage_folder, params, tenant_id) do
    Kontor.Mail.manage_folder(params, tenant_id)
  end

  defp log_execution(state, action, params, tenant_id, result) do
    entry = %{
      action: action,
      tenant_id: tenant_id,
      params_keys: Map.keys(params),
      success: match?({:ok, _}, result),
      timestamp: DateTime.utc_now()
    }
    %{state | execution_log: [entry | Enum.take(state.execution_log, 999)]}
  end
end
