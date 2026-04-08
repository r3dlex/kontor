defmodule Kontor.Repo.Migrations.AddFolderModelToMailboxes do
  use Ecto.Migration

  def change do
    alter table(:mailboxes) do
      add :folder_model, :string, default: "structural_category", null: false
      add :folder_bootstrap_count, :integer, default: 0, null: false
      add :folder_model_locked_at, :utc_datetime, null: true
    end
  end
end
