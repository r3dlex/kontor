defmodule Kontor.Mail.FolderOrganizerWorker do
  @moduledoc "Nightly Oban worker: applies pending folder suggestions from AI pipeline."
  use Oban.Worker, queue: :folder_organizer, max_attempts: 3

  require Logger
  import Ecto.Query

  alias Kontor.Repo
  alias Kontor.Mail.FolderSuggestion
  alias Kontor.Accounts.Mailbox

  @impl Oban.Worker
  def perform(_job) do
    pending =
      Repo.all(
        from s in FolderSuggestion,
          where: s.status == "pending",
          order_by: [asc: s.inserted_at],
          limit: 200,
          preload: [:mailbox, :email]
      )

    Enum.each(pending, &apply_suggestion/1)
    :ok
  end

  defp apply_suggestion(%FolderSuggestion{mailbox: nil} = s) do
    mark(s, "failed")
  end

  defp apply_suggestion(%FolderSuggestion{mailbox: %Mailbox{} = mailbox} = suggestion) do
    config = mailbox.himalaya_config

    with :ok <- maybe_create_folder(config, suggestion),
         :ok <- move_email(config, suggestion) do
      mark(suggestion, "applied")
    else
      {:error, reason} ->
        Logger.warning("FolderOrganizerWorker: failed to apply suggestion #{suggestion.id}: #{inspect(reason)}")
        mark(suggestion, "failed")
    end
  end

  defp maybe_create_folder(_config, %{create_if_missing: false}), do: :ok

  defp maybe_create_folder(config, %{suggested_folder: folder, create_if_missing: true}) do
    case Kontor.MCP.HimalayaClient.create_folder(config, folder) do
      {:ok, _} -> :ok
      {:error, :already_exists} -> :ok
      error -> error
    end
  end

  defp move_email(_config, %{email: nil}), do: {:error, :email_not_found}

  defp move_email(config, %{email: email, suggested_folder: folder}) do
    case Kontor.MCP.HimalayaClient.move_email(config, email.message_id, folder) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp mark(suggestion, status) do
    Repo.update_all(
      from(s in FolderSuggestion, where: s.id == ^suggestion.id),
      set: [status: status]
    )
  end
end
