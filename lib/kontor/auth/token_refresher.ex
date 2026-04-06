defmodule Kontor.Auth.TokenRefresher do
  @moduledoc "Eagerly refreshes OAuth tokens at 80% of token lifetime elapsed."
  use GenServer
  require Logger

  @check_interval_ms 5 * 60 * 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check, state) do
    refresh_expiring_tokens()
    schedule_check()
    {:noreply, state}
  end

  defp refresh_expiring_tokens do
    import Ecto.Query

    now = DateTime.utc_now()
    threshold_minutes = 20  # refresh if expiring within 20 minutes (80% of ~60-120 min typical lifetime)
    threshold = DateTime.add(now, threshold_minutes * 60)

    credentials =
      Kontor.Repo.all(
        from c in Kontor.Accounts.Credential,
        where: c.expires_at <= ^threshold
      )

    Enum.each(credentials, &refresh_credential/1)
  end

  defp refresh_credential(%{provider: "google"} = credential) do
    do_refresh(Kontor.Auth.Google, credential)
  end

  defp refresh_credential(%{provider: "microsoft"} = credential) do
    do_refresh(Kontor.Auth.Microsoft, credential)
  end

  defp refresh_credential(_credential), do: :ok

  defp do_refresh(module, credential) do
    case module.refresh_token(credential) do
      {:ok, new_cred} ->
        Logger.info("Refreshed #{credential.provider} token for tenant #{credential.tenant_id}")
        new_cred
      {:error, reason} ->
        Logger.warning("Failed to refresh #{credential.provider} token: #{inspect(reason)}")
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check, @check_interval_ms)
  end
end
