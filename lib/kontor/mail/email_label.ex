defmodule Kontor.Mail.EmailLabel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "email_labels" do
    field :tenant_id, :string
    field :labels, {:array, :string}, default: []
    field :priority_score, :integer
    field :has_actionable_task, :boolean, default: false
    field :task_summary, :string
    field :task_deadline, :utc_datetime
    field :ai_confidence, :float
    field :ai_reasoning, :string
    field :inserted_at, :utc_datetime

    belongs_to :email, Kontor.Mail.Email
  end

  def changeset(email_label, attrs) do
    email_label
    |> cast(attrs, [:tenant_id, :email_id, :labels, :priority_score, :has_actionable_task,
                    :task_summary, :task_deadline, :ai_confidence, :ai_reasoning, :inserted_at])
    |> validate_required([:tenant_id, :email_id])
    |> validate_number(:priority_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:email_id)
  end
end
