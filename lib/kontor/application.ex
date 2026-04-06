defmodule Kontor.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Kontor.Repo,
      Kontor.Vault,
      {Phoenix.PubSub, name: Kontor.PubSub},
      KontorWeb.Endpoint,
      Kontor.Cache,
      {Oban, Application.fetch_env!(:kontor, Oban)},
      Kontor.MCP.Supervisor,
      Kontor.Mail.Supervisor,
      Kontor.AI.Supervisor,
      Kontor.Calendar.Supervisor,
      Kontor.Tasks.Supervisor,
      Kontor.Contacts.Supervisor,
      Kontor.Auth.TokenRefresher
    ]

    opts = [strategy: :one_for_one, name: Kontor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    KontorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
