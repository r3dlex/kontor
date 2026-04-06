defmodule Kontor.MCP.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Kontor.MCP.HimalayaClient,
      Kontor.MCP.AsanaClient,
      Kontor.MCP.GoogleCalendarClient,
      Kontor.MCP.OutboundServer
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
