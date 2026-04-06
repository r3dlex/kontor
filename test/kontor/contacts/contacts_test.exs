defmodule Kontor.ContactsTest do
  use Kontor.DataCase, async: true

  alias Kontor.Contacts

  @tenant "tenant-contacts-test"

  # ---------------------------------------------------------------------------
  # list_contacts/2
  # ---------------------------------------------------------------------------

  describe "list_contacts/2" do
    test "returns all contacts for tenant ordered by importance_weight descending" do
      insert(:contact, tenant_id: @tenant, email_address: "a@e.com", importance_weight: 0.2)
      insert(:contact, tenant_id: @tenant, email_address: "b@e.com", importance_weight: 0.9)
      insert(:contact, tenant_id: @tenant, email_address: "c@e.com", importance_weight: 0.5)

      contacts = Contacts.list_contacts(@tenant)

      assert length(contacts) == 3
      weights = Enum.map(contacts, & &1.importance_weight)
      assert weights == Enum.sort(weights, :desc)
    end

    test "returns empty list when no contacts exist for tenant" do
      assert Contacts.list_contacts(@tenant) == []
    end

    test "does not return contacts from another tenant" do
      insert(:contact, tenant_id: "other-tenant", email_address: "other@e.com")

      assert Contacts.list_contacts(@tenant) == []
    end

    test "filters contacts by organization when option provided" do
      insert(:contact, tenant_id: @tenant, email_address: "acme1@e.com", organization: "ACME")
      insert(:contact, tenant_id: @tenant, email_address: "acme2@e.com", organization: "ACME")
      insert(:contact, tenant_id: @tenant, email_address: "other@e.com", organization: "Other Corp")

      results = Contacts.list_contacts(@tenant, organization: "ACME")

      assert length(results) == 2
      assert Enum.all?(results, &(&1.organization == "ACME"))
    end

    test "returns all contacts when organization filter is nil" do
      insert(:contact, tenant_id: @tenant, email_address: "x@e.com", organization: "Org1")
      insert(:contact, tenant_id: @tenant, email_address: "y@e.com", organization: "Org2")

      assert length(Contacts.list_contacts(@tenant, organization: nil)) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # get_contact/2
  # ---------------------------------------------------------------------------

  describe "get_contact/2" do
    test "returns {:ok, contact} when contact is found for tenant" do
      contact = insert(:contact, tenant_id: @tenant)

      assert {:ok, found} = Contacts.get_contact(contact.id, @tenant)
      assert found.id == contact.id
    end

    test "returns {:error, :not_found} when contact id does not exist" do
      assert {:error, :not_found} = Contacts.get_contact(Ecto.UUID.generate(), @tenant)
    end

    test "returns {:error, :not_found} when contact belongs to different tenant" do
      contact = insert(:contact, tenant_id: "other-tenant", email_address: "x@e.com")

      assert {:error, :not_found} = Contacts.get_contact(contact.id, @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # upsert_contact/3
  # ---------------------------------------------------------------------------

  describe "upsert_contact/3 — insert path" do
    test "inserts a new contact when email does not exist for tenant" do
      email = "new@example.com"
      attrs = %{display_name: "New Person", organization: "ACME"}

      assert {:ok, contact} = Contacts.upsert_contact(email, attrs, @tenant)
      assert contact.email_address == email
      assert contact.display_name == "New Person"
      assert contact.tenant_id == @tenant
    end

    test "sets first_seen and last_seen on insert" do
      before = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, contact} = Contacts.upsert_contact("fresh@example.com", %{}, @tenant)

      assert DateTime.compare(contact.first_seen, before) in [:gt, :eq]
      assert DateTime.compare(contact.last_seen, before) in [:gt, :eq]
    end

    test "inserts contact with same email for different tenant" do
      insert(:contact, tenant_id: "other-tenant", email_address: "shared@e.com")

      assert {:ok, contact} = Contacts.upsert_contact("shared@e.com", %{}, @tenant)
      assert contact.tenant_id == @tenant
    end
  end

  describe "upsert_contact/3 — update path" do
    test "updates existing contact when email already exists for tenant" do
      insert(:contact, tenant_id: @tenant, email_address: "existing@e.com",
             display_name: "Old Name")

      assert {:ok, updated} = Contacts.upsert_contact("existing@e.com",
                                %{display_name: "New Name"}, @tenant)
      assert updated.display_name == "New Name"
      assert updated.email_address == "existing@e.com"
    end

    test "updates last_seen timestamp on update" do
      old_time = DateTime.add(DateTime.utc_now(), -3600) |> DateTime.truncate(:second)
      insert(:contact, tenant_id: @tenant, email_address: "update@e.com", last_seen: old_time)

      {:ok, updated} = Contacts.upsert_contact("update@e.com", %{}, @tenant)

      assert DateTime.compare(updated.last_seen, old_time) == :gt
    end

    test "does not change first_seen on update" do
      fixed_time = DateTime.add(DateTime.utc_now(), -7200) |> DateTime.truncate(:second)
      insert(:contact, tenant_id: @tenant, email_address: "first@e.com",
             first_seen: fixed_time, last_seen: fixed_time)

      {:ok, updated} = Contacts.upsert_contact("first@e.com", %{display_name: "Updated"}, @tenant)

      assert DateTime.compare(updated.first_seen, fixed_time) == :eq
    end
  end

  # ---------------------------------------------------------------------------
  # graph_data/1
  # ---------------------------------------------------------------------------

  describe "graph_data/1" do
    test "returns nodes and edges map" do
      result = Contacts.graph_data(@tenant)

      assert Map.has_key?(result, :nodes)
      assert Map.has_key?(result, :edges)
    end

    test "nodes contain id, label, title, value fields for each contact" do
      insert(:contact, tenant_id: @tenant, email_address: "graph@e.com",
             display_name: "Graph User", organization: "GraphCo", importance_weight: 0.8)

      %{nodes: nodes} = Contacts.graph_data(@tenant)

      assert length(nodes) == 1
      [node] = nodes
      assert Map.has_key?(node, :id)
      assert Map.has_key?(node, :label)
      assert Map.has_key?(node, :title)
      assert Map.has_key?(node, :value)
    end

    test "node label uses display_name when available" do
      insert(:contact, tenant_id: @tenant, email_address: "named@e.com", display_name: "Named Person")

      %{nodes: [node]} = Contacts.graph_data(@tenant)

      assert node.label == "Named Person"
    end

    test "node label falls back to email_address when display_name is nil" do
      insert(:contact, tenant_id: @tenant, email_address: "noname@e.com", display_name: nil)

      %{nodes: [node]} = Contacts.graph_data(@tenant)

      assert node.label == "noname@e.com"
    end

    test "returns empty nodes and edges when no contacts or relationships exist" do
      %{nodes: nodes, edges: edges} = Contacts.graph_data(@tenant)

      assert nodes == []
      assert edges == []
    end

    test "nodes do not include contacts from other tenants" do
      insert(:contact, tenant_id: "other-tenant", email_address: "other@e.com")

      %{nodes: nodes} = Contacts.graph_data(@tenant)

      assert nodes == []
    end
  end
end
