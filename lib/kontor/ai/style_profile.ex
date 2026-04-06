defmodule Kontor.AI.StyleProfile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "style_profiles" do
    field :tenant_id, :string
    field :name, :string
    field :content, :string
    field :preserve_voice, :boolean, default: false
    field :auto_select_rules, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:tenant_id, :name, :content, :preserve_voice, :auto_select_rules])
    |> validate_required([:tenant_id, :name, :content])
    |> unique_constraint([:tenant_id, :name])
  end
end
