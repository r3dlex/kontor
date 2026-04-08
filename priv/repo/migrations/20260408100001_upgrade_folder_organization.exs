defmodule Kontor.Repo.Migrations.UpgradeFolderOrganization do
  use Ecto.Migration

  def change do
    create table(:email_labels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :email_id, references(:emails, type: :binary_id, on_delete: :delete_all), null: false
      add :labels, {:array, :string}, default: []
      add :priority_score, :integer
      add :has_actionable_task, :boolean, default: false
      add :task_summary, :string
      add :task_deadline, :utc_datetime
      add :ai_confidence, :float
      add :ai_reasoning, :string
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:email_labels, [:tenant_id])
    create unique_index(:email_labels, [:email_id])

    create table(:sender_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :mailbox_id, references(:mailboxes, type: :binary_id, on_delete: :delete_all), null: false
      add :sender_pattern, :string, null: false
      add :rule_type, :string
      add :rule_data, :map
      add :confidence, :string
      add :correction_count, :integer, default: 0
      add :source, :string
      add :active, :boolean, default: true
      timestamps(type: :utc_datetime)
    end

    create unique_index(:sender_rules, [:tenant_id, :mailbox_id, :sender_pattern])
    create index(:sender_rules, [:mailbox_id, :rule_type])

    create table(:folder_corrections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :mailbox_id, references(:mailboxes, type: :binary_id, on_delete: :delete_all), null: false
      add :email_id, references(:emails, type: :binary_id, on_delete: :delete_all), null: false
      add :from_folder, :string
      add :to_folder, :string
      add :sender, :string
      add :sender_domain, :string
      add :recorded_at, :utc_datetime
    end

    create index(:folder_corrections, [:tenant_id, :mailbox_id, :sender])
    create index(:folder_corrections, [:mailbox_id, :sender_domain])

    create table(:newsletter_engagement, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :string, null: false
      add :mailbox_id, references(:mailboxes, type: :binary_id, on_delete: :delete_all), null: false
      add :sender_domain, :string, null: false
      add :consecutive_unread, :integer, default: 0
      add :last_received_at, :utc_datetime
      add :auto_archive, :boolean, default: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:newsletter_engagement, [:mailbox_id, :sender_domain])

    alter table(:folder_suggestions) do
      add :labels, {:array, :string}, default: []
      add :priority_score, :integer
      add :reasoning, :string
    end

    alter table(:mailboxes) do
      add :folder_creation_guard, :map,
        default: %{"volume_threshold" => 5, "confidence_min" => 0.80, "max_active_folders" => 12}
    end
  end
end
