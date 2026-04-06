defmodule Kontor.AI.SkillVersion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "skill_versions" do
    field :version, :integer
    field :content, :string
    field :author, Ecto.Enum, values: [:system, :llm, :user]
    field :diff, :string

    belongs_to :skill, Kontor.AI.Skill

    timestamps(type: :utc_datetime)
  end

  def changeset(sv, attrs) do
    sv
    |> cast(attrs, [:skill_id, :version, :content, :author, :diff])
    |> validate_required([:skill_id, :version, :content])
  end
end
