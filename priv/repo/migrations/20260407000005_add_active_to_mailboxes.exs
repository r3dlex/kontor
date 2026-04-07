defmodule Kontor.Repo.Migrations.AddActiveToMailboxes do
  use Ecto.Migration

  def change do
    alter table(:mailboxes) do
      add :active, :boolean, default: true, null: false
    end

    create index(:mailboxes, [:active])
  end
end
