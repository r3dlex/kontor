defmodule Kontor.Repo.Migrations.CreateFolderSuggestions do
  use Ecto.Migration

  def change do
    create table(:folder_suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :mailbox_id, references(:mailboxes, type: :binary_id, on_delete: :delete_all), null: false
      add :email_id, references(:emails, type: :binary_id, on_delete: :delete_all), null: false
      add :email_message_id, :string, null: false
      add :suggested_folder, :string, null: false
      add :current_folder, :string
      add :create_if_missing, :boolean, default: false, null: false
      add :status, :string, default: "pending", null: false
      add :confidence, :float, null: false
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create index(:folder_suggestions, [:tenant_id])
    create index(:folder_suggestions, [:mailbox_id, :status, :inserted_at])
    create unique_index(:folder_suggestions, [:email_id])
  end
end
