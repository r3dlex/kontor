defmodule Kontor.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @task_types [:reply, :meeting_setup, :calendar_reminder, :custom]
  @statuses [:created, :confirmed, :in_progress, :done, :dismissed, :expired]

  schema "tasks" do
    field :tenant_id, :string
    field :task_type, Ecto.Enum, values: @task_types
    field :title, :string
    field :description, :string
    field :importance, :float, default: 0.0
    field :status, Ecto.Enum, values: @statuses, default: :created
    field :confidence, :float, default: 0.0
    field :draft_content, :string
    field :style_profile_used, :string
    field :asana_sync_id, :string
    field :scheduled_action_at, :utc_datetime
    field :thread_id, :binary_id
    field :email_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:tenant_id, :thread_id, :email_id, :task_type, :title, :description,
                    :importance, :status, :confidence, :draft_content,
                    :style_profile_used, :asana_sync_id, :scheduled_action_at])
    |> validate_required([:tenant_id, :task_type, :title])
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end

  def should_auto_confirm?(%__MODULE__{confidence: c}) do
    c >= Application.get_env(:kontor, :tasks)[:auto_confirm_threshold_high]
  end

  def should_surface?(%__MODULE__{confidence: c}) do
    c >= Application.get_env(:kontor, :tasks)[:auto_confirm_threshold_low]
  end
end
