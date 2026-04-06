defmodule Kontor.Mail.Thread do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "threads" do
    field :tenant_id, :string
    field :thread_id, :string
    field :markdown_content, :string
    field :last_updated, :utc_datetime
    field :score_urgency, :float, default: 0.0
    field :score_action, :float, default: 0.0
    field :score_authority, :float, default: 0.0
    field :score_momentum, :float, default: 0.0
    field :composite_score, :float, default: 0.0

    timestamps(type: :utc_datetime)
  end

  def changeset(thread, attrs) do
    thread
    |> cast(attrs, [:tenant_id, :thread_id, :markdown_content, :last_updated,
                    :score_urgency, :score_action, :score_authority,
                    :score_momentum, :composite_score])
    |> validate_required([:tenant_id, :thread_id])
    |> unique_constraint([:tenant_id, :thread_id])
  end

  def composite_score(%__MODULE__{} = t) do
    # Default equal weighting; weights come from user preferences markdown
    (t.score_urgency + t.score_action + t.score_authority + t.score_momentum) / 4.0
  end
end
