defmodule Kontor.Mail.SenderRulePromotionWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.Mail.FolderCorrection

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    corrections_query =
      from fc in FolderCorrection,
      group_by: [fc.tenant_id, fc.mailbox_id, fc.sender, fc.to_folder],
      having: count(fc.id) >= 3,
      select: %{
        tenant_id: fc.tenant_id,
        mailbox_id: fc.mailbox_id,
        sender: fc.sender,
        to_folder: fc.to_folder,
        count: count(fc.id)
      }

    Repo.all(corrections_query)
    |> Enum.each(fn %{tenant_id: tid, mailbox_id: mid, sender: sender, to_folder: folder, count: cnt} ->
      Kontor.Mail.upsert_sender_rule(%{
        tenant_id: tid,
        mailbox_id: mid,
        sender_pattern: sender,
        rule_type: "folder_override",
        rule_data: %{"folder" => folder},
        confidence: "confident",
        correction_count: cnt,
        source: "user_correction",
        active: true
      }, tid)
    end)

    :ok
  end
end
