defmodule Kontor.Contacts do
  @moduledoc "Context module for contact intelligence."

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.Contacts.{Contact, ContactMailboxContext, ContactRelationship, OrgChart}

  # --- Contacts ---

  def list_contacts(tenant_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query = from c in Contact, where: c.tenant_id == ^tenant_id, order_by: [desc: :importance_weight]

    query
    |> maybe_filter_org(opts[:organization])
    |> maybe_filter_mailbox_context(opts[:mailbox_id])
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def get_contact(id, tenant_id) do
    case Repo.get_by(Contact, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      contact -> {:ok, contact}
    end
  end

  def get_contact_by_email(email, tenant_id) do
    Repo.get_by(Contact, email_address: email, tenant_id: tenant_id)
  end

  def upsert_contact(email, attrs, tenant_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case get_contact_by_email(email, tenant_id) do
      nil ->
        attrs = Map.merge(attrs, %{tenant_id: tenant_id, email_address: email, first_seen: now, last_seen: now})
        %Contact{} |> Contact.changeset(attrs) |> Repo.insert()
      contact ->
        attrs = Map.put(attrs, :last_seen, now)
        contact |> Contact.changeset(attrs) |> Repo.update()
    end
  end

  def update_profile(id, markdown, tenant_id) do
    with {:ok, contact} <- get_contact(id, tenant_id) do
      contact |> Contact.changeset(%{profile_markdown: markdown}) |> Repo.update()
    end
  end

  def graph_data(tenant_id) do
    contacts = list_contacts(tenant_id)
    relationships = Repo.all(from r in ContactRelationship, where: r.tenant_id == ^tenant_id)

    nodes = Enum.map(contacts, fn c ->
      %{id: c.id, label: c.display_name || c.email_address,
        title: c.organization, value: c.importance_weight}
    end)

    edges = Enum.map(relationships, fn r ->
      %{from: r.contact_a_id, to: r.contact_b_id,
        value: r.weight, title: r.relationship_type}
    end)

    %{nodes: nodes, edges: edges}
  end

  # --- Mailbox Context ---

  def upsert_mailbox_context(contact_id, mailbox_id, attrs, tenant_id) do
    case Repo.get_by(ContactMailboxContext, contact_id: contact_id, mailbox_id: mailbox_id) do
      nil ->
        attrs = Map.merge(attrs, %{tenant_id: tenant_id, contact_id: contact_id, mailbox_id: mailbox_id})
        %ContactMailboxContext{} |> ContactMailboxContext.changeset(attrs) |> Repo.insert()
      ctx ->
        ctx |> ContactMailboxContext.changeset(attrs) |> Repo.update()
    end
  end

  # --- Relationships ---

  def upsert_relationship(contact_a_id, contact_b_id, type, attrs, tenant_id) do
    case Repo.get_by(ContactRelationship,
           tenant_id: tenant_id, contact_a_id: contact_a_id,
           contact_b_id: contact_b_id, relationship_type: type) do
      nil ->
        attrs = Map.merge(attrs, %{
          tenant_id: tenant_id, contact_a_id: contact_a_id,
          contact_b_id: contact_b_id, relationship_type: type,
          last_updated: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        %ContactRelationship{} |> ContactRelationship.changeset(attrs) |> Repo.insert()
      rel ->
        attrs = Map.put(attrs, :last_updated, DateTime.utc_now() |> DateTime.truncate(:second))
        rel |> ContactRelationship.changeset(attrs) |> Repo.update()
    end
  end

  # --- Org Charts ---

  def list_org_charts(tenant_id) do
    Repo.all(from o in OrgChart, where: o.tenant_id == ^tenant_id)
  end

  def get_org_chart(id, tenant_id) do
    case Repo.get_by(OrgChart, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      chart -> {:ok, chart}
    end
  end

  def create_org_chart(attrs, tenant_id) do
    attrs =
      Map.new(attrs, fn
        {k, v} when is_atom(k) -> {Atom.to_string(k), v}
        {k, v} -> {k, v}
      end)
      |> Map.put("tenant_id", tenant_id)
    %OrgChart{}
    |> OrgChart.changeset(attrs)
    |> Repo.insert()
  end

  def update_org_chart(id, attrs, tenant_id) do
    with {:ok, chart} <- get_org_chart(id, tenant_id) do
      chart |> OrgChart.changeset(attrs) |> Repo.update()
    end
  end

  # 2-arg version for OrgChartController (struct + attrs)
  def update_org_chart(%OrgChart{} = chart, attrs) do
    chart |> OrgChart.changeset(attrs) |> Repo.update()
  end

  # Alias for ContactController compatibility
  def get_relationship_graph(tenant_id), do: graph_data(tenant_id)

  def resynthesize_profile(id, tenant_id) do
    case get_contact(id, tenant_id) do
      {:error, _} = err -> err
      {:ok, contact} ->
        input = %{
          email_address: contact.email_address,
          display_name: contact.display_name,
          organization: contact.organization
        }
        case Kontor.AI.Pipeline.run_skill("contact_organizer", input, tenant_id) do
          {:ok, result} ->
            md = Map.get(result, "profile_markdown", "## Profile\n\nNo profile generated.")
            update_profile(id, md, tenant_id)
          {:error, _} -> {:ok, contact}
        end
    end
  end

  defp maybe_filter_org(query, nil), do: query
  defp maybe_filter_org(query, org) do
    where(query, [c], c.organization == ^org)
  end

  defp maybe_filter_mailbox_context(query, nil), do: query
  defp maybe_filter_mailbox_context(query, mailbox_id) do
    join(query, :inner, [c], mc in Kontor.Contacts.ContactMailboxContext,
      on: mc.contact_id == c.id and mc.mailbox_id == ^mailbox_id)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
