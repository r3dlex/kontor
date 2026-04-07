defmodule Kontor.Documents do
  @moduledoc "Context module for persistent document storage (transcripts, meeting minutes, notes, reports)."

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.Documents.Document

  @doc "Insert a new document for the given tenant."
  def push_document(tenant_id, type, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.merge(%{"tenant_id" => tenant_id, "type" => type})

    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
  end

  @doc "List documents for a tenant with optional filtering."
  def list_documents(tenant_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from d in Document,
        where: d.tenant_id == ^tenant_id,
        order_by: [desc: d.inserted_at]

    query
    |> maybe_filter_type(opts[:type])
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc "Fetch a single document by id scoped to tenant."
  def get_document(id, tenant_id) do
    case Repo.get_by(Document, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      document -> {:ok, document}
    end
  end

  defp maybe_filter_type(query, nil), do: query
  defp maybe_filter_type(query, type) do
    where(query, [d], d.type == ^type)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
