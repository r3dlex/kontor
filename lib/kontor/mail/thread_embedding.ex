defmodule Kontor.Mail.ThreadEmbedding do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_embeddings" do
    field :tenant_id, :string
    field :thread_id, :binary_id
    field :embedding, Pgvector.Ecto.Vector

    timestamps(type: :utc_datetime)
  end

  def changeset(te, attrs) do
    te
    |> cast(attrs, [:tenant_id, :thread_id, :embedding])
    |> validate_required([:tenant_id, :thread_id, :embedding])
  end
end
