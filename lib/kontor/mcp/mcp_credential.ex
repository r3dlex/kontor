defmodule Kontor.MCP.McpCredential do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mcp_credentials" do
    field :tenant_id, :string
    field :server_name, :string
    field :token_hash, :string
    field :permissions, {:array, :string}, default: []
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(cred, attrs) do
    cred
    |> cast(attrs, [:tenant_id, :server_name, :token_hash, :permissions, :active])
    |> validate_required([:tenant_id, :server_name])
  end
end
