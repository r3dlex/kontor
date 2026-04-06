defmodule Kontor.AI.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "skills" do
    field :tenant_id, :string
    field :namespace, :string
    field :name, :string
    field :version, :integer, default: 1
    field :content, :string
    field :author, Ecto.Enum, values: [:system, :llm, :user]
    field :locked, :boolean, default: false
    field :active, :boolean, default: true
    field :webhook_url, :string

    has_many :versions, Kontor.AI.SkillVersion

    timestamps(type: :utc_datetime)
  end

  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [:tenant_id, :namespace, :name, :version, :content,
                    :author, :locked, :active, :webhook_url])
    |> validate_required([:tenant_id, :namespace, :name, :content])
    |> unique_constraint([:tenant_id, :namespace, :name])
  end
end
