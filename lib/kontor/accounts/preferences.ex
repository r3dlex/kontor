defmodule Kontor.Accounts.Preferences do
  @moduledoc "Ecto schema for persistent user preferences (theme, polling config, UI settings)."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_preferences" do
    field :tenant_id, :string
    field :theme, :string, default: "system"
    field :polling_interval_seconds, :integer, default: 60
    field :read_only_mode, :boolean, default: false
    field :font_size, :string, default: "medium"
    field :extra, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(preferences, attrs) do
    preferences
    |> cast(attrs, [:tenant_id, :theme, :polling_interval_seconds, :read_only_mode, :font_size, :extra])
    |> validate_required([:tenant_id])
    |> unique_constraint(:tenant_id)
    |> validate_inclusion(:theme, ["light", "dark", "system"])
    |> validate_inclusion(:font_size, ["small", "medium", "large"])
    |> validate_number(:polling_interval_seconds, greater_than: 0)
  end
end
