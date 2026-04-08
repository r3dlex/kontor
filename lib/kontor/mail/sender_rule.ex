defmodule Kontor.Mail.SenderRule do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sender_rules" do
    field :tenant_id, :string
    field :sender_pattern, :string
    field :rule_type, :string
    field :rule_data, :map
    field :confidence, :string
    field :correction_count, :integer, default: 0
    field :source, :string
    field :active, :boolean, default: true

    belongs_to :mailbox, Kontor.Accounts.Mailbox
    timestamps(type: :utc_datetime)
  end

  def changeset(sender_rule, attrs) do
    sender_rule
    |> cast(attrs, [:tenant_id, :mailbox_id, :sender_pattern, :rule_type, :rule_data,
                    :confidence, :correction_count, :source, :active])
    |> validate_required([:tenant_id, :mailbox_id, :sender_pattern, :rule_type])
    |> validate_inclusion(:rule_type, ["folder_override", "auto_archive", "label_override"])
    |> validate_inclusion(:confidence, ["tentative", "confident"])
    |> foreign_key_constraint(:mailbox_id)
  end
end
