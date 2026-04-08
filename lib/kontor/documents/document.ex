defmodule Kontor.Documents.Document do
  @moduledoc "Ecto schema for persistent document storage (transcripts, meeting minutes, notes, reports)."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "documents" do
    field :tenant_id, :string
    field :type, Ecto.Enum, values: [:transcript, :meeting_minutes, :note, :report, :other], default: :other
    field :title, :string
    field :content, :string
    field :source, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:tenant_id, :type, :title, :content, :source, :metadata])
    |> validate_required([:tenant_id, :title])
  end
end
