defmodule Kontor.Mail.ScheduledSender do
  @moduledoc "Oban worker that fires scheduled email sends via Himalaya MCP."
  use Oban.Worker, queue: :mailer, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"draft_id" => draft_id, "tenant_id" => tenant_id}}) do
    import Ecto.Query

    case Kontor.Repo.get_by(Kontor.Mail.ScheduledSend,
           id: draft_id, tenant_id: tenant_id, status: :pending) do
      nil ->
        Logger.info("ScheduledSender: draft #{draft_id} not found or already sent")
        :ok

      draft ->
        case Kontor.MCP.HimalayaClient.send_email(draft) do
          {:ok, _} ->
            draft
            |> Kontor.Mail.ScheduledSend.changeset(%{
              status: :sent,
              sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
            })
            |> Kontor.Repo.update()

            Logger.info("ScheduledSender: sent draft #{draft_id}")
            :ok

          {:error, reason} ->
            Logger.error("ScheduledSender: failed to send draft #{draft_id}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  def schedule(draft_id, tenant_id, scheduled_at) do
    %{"draft_id" => draft_id, "tenant_id" => tenant_id}
    |> new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end
end
