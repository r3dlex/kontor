defmodule Kontor.MCP.OutboundServer do
  @moduledoc """
  Kontor's outbound MCP server. Exposes five namespaces:
  Calendar, Documents, Configuration, Skills, Automations.
  Open on localhost. Auth stubs on every handler for future remote access.
  """
  use GenServer
  require Logger

  @port 9090

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    port = Application.get_env(:kontor, :mcp_outbound_port, @port)
    {:ok, _} = Plug.Cowboy.http(Kontor.MCP.OutboundServer.Router, [], port: port)
    Logger.info("MCP outbound server listening on port #{port}")
    {:ok, %{port: port}}
  end
end

defmodule Kontor.MCP.OutboundServer.Router do
  use Plug.Router

  require Logger

  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :match
  plug :dispatch

  post "/mcp/call" do
    case check_mcp_auth(conn) do
      :ok ->
        tenant_id = get_req_header(conn, "x-tenant-id") |> List.first() || "default"
        %{"method" => method, "params" => params} = conn.body_params

        case dispatch_method(method, params, tenant_id) do
          {:ok, data} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(%{result: data}))

          {:error, reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, Jason.encode!(%{error: inspect(reason)}))
        end

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "unauthorized: #{reason}"}))
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp check_mcp_auth(conn) do
    if Application.get_env(:kontor, :mcp, []) |> Keyword.get(:require_mcp_auth, false) do
      case get_req_header(conn, "authorization") do
        ["Bearer " <> token] -> verify_mcp_token(token)
        _ -> {:error, "missing authorization header"}
      end
    else
      :ok
    end
  end

  defp verify_mcp_token(token) do
    case KontorWeb.Auth.verify_token(token) do
      {:ok, claims} ->
        if Map.get(claims, "mcp") == true do
          {:ok, claims}
        else
          {:error, "token does not grant MCP access"}
        end

      {:error, _reason} ->
        {:error, "invalid or expired token"}
    end
  end

  # Calendar namespace
  defp dispatch_method("calendar/list_events", _params, tenant_id) do
    events = Kontor.Calendar.list_today_events(tenant_id)
    {:ok, Enum.map(events, &event_to_map/1)}
  end

  defp dispatch_method("calendar/create_event", params, tenant_id) do
    Kontor.MCP.GoogleCalendarClient.create_event(tenant_id, params)
  end

  defp dispatch_method("calendar/get_briefing", %{"event_id" => id}, tenant_id) do
    with {:ok, event} <- Kontor.Calendar.get_event(id, tenant_id) do
      {:ok, %{briefing: event.briefing_markdown, event: event_to_map(event)}}
    end
  end

  # Documents namespace
  defp dispatch_method("documents/push", %{"type" => type, "content" => content}, tenant_id) do
    Logger.info("Document pushed via MCP: type=#{type}, tenant=#{tenant_id}")
    {:ok, %{received: true, type: type, length: String.length(content)}}
  end

  # Configuration namespace
  defp dispatch_method("config/get", _params, tenant_id) do
    user = Kontor.Repo.get_by(Kontor.Accounts.User, tenant_id: tenant_id)
    {:ok, %{tenant_id: tenant_id, user_id: user && user.id}}
  end

  defp dispatch_method("config/set", params, tenant_id) do
    Logger.info("Config set via MCP: #{inspect(params)}, tenant=#{tenant_id}")
    {:ok, %{updated: true}}
  end

  # Skills namespace
  defp dispatch_method("skills/list", _params, tenant_id) do
    skills = Kontor.AI.Skills.list_skills(tenant_id)
    {:ok, Enum.map(skills, &skill_to_map/1)}
  end

  defp dispatch_method("skills/get", %{"name" => name}, tenant_id) do
    case Kontor.AI.Skills.get_skill_by_name(name, tenant_id) do
      nil -> {:error, :not_found}
      skill -> {:ok, skill_to_map(skill)}
    end
  end

  defp dispatch_method("skills/trigger", %{"name" => name, "input" => input}, tenant_id) do
    Kontor.AI.Pipeline.run_skill(name, input, tenant_id)
  end

  # Automations namespace
  defp dispatch_method("automations/trigger", %{"skill" => skill, "input" => input}, tenant_id) do
    Kontor.AI.Pipeline.run_skill(skill, input, tenant_id)
  end

  defp dispatch_method("automations/register_webhook", params, tenant_id) do
    Logger.info("Webhook registered via MCP: #{inspect(params)}, tenant=#{tenant_id}")
    {:ok, %{registered: true}}
  end

  defp dispatch_method(method, _params, _tenant_id) do
    {:error, "Unknown method: #{method}"}
  end

  defp event_to_map(event) do
    %{
      id: event.id,
      provider: event.provider,
      title: event.title,
      start_time: event.start_time,
      end_time: event.end_time,
      attendees: event.attendees,
      location: event.location
    }
  end

  defp skill_to_map(skill) do
    %{
      id: skill.id,
      name: skill.name,
      namespace: skill.namespace,
      version: skill.version,
      locked: skill.locked,
      active: skill.active
    }
  end
end
