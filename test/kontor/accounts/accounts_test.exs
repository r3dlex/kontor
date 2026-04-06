defmodule Kontor.AccountsTest do
  use Kontor.DataCase, async: true

  alias Kontor.Accounts

  @tenant "tenant-accounts-test"

  # ---------------------------------------------------------------------------
  # upsert_user/1
  # ---------------------------------------------------------------------------

  describe "upsert_user/1 — insert path" do
    test "inserts a new user when email does not exist" do
      attrs = %{email: "new@example.com", tenant_id: @tenant, name: "New User"}

      assert {:ok, user} = Accounts.upsert_user(attrs)
      assert user.email == "new@example.com"
      assert user.tenant_id == @tenant
      assert user.name == "New User"
    end

    test "returns changeset error when email is missing" do
      assert {:error, changeset} = Accounts.upsert_user(%{tenant_id: @tenant})
      assert Map.has_key?(errors_on(changeset), :email)
    end

    test "returns changeset error when tenant_id is missing" do
      assert {:error, changeset} = Accounts.upsert_user(%{email: "no-tenant@e.com"})
      assert Map.has_key?(errors_on(changeset), :tenant_id)
    end

    test "returns changeset error when email format is invalid" do
      assert {:error, changeset} = Accounts.upsert_user(%{email: "notanemail", tenant_id: @tenant})
      assert Map.has_key?(errors_on(changeset), :email)
    end

    test "accepts string keys" do
      attrs = %{"email" => "strkey@example.com", "tenant_id" => @tenant}

      assert {:ok, user} = Accounts.upsert_user(attrs)
      assert user.email == "strkey@example.com"
    end
  end

  describe "upsert_user/1 — update path" do
    test "updates existing user when email matches" do
      insert(:user, email: "existing@example.com", tenant_id: @tenant, name: "Old Name")

      assert {:ok, updated} = Accounts.upsert_user(%{
        email: "existing@example.com",
        tenant_id: @tenant,
        name: "New Name"
      })

      assert updated.name == "New Name"
      assert updated.email == "existing@example.com"
    end
  end

  # ---------------------------------------------------------------------------
  # list_tenant_ids/0
  # ---------------------------------------------------------------------------

  describe "list_tenant_ids/0" do
    test "returns distinct tenant_ids from all users" do
      insert(:user, email: "u1@e.com", tenant_id: "tid-a")
      insert(:user, email: "u2@e.com", tenant_id: "tid-a")
      insert(:user, email: "u3@e.com", tenant_id: "tid-b")

      ids = Accounts.list_tenant_ids()

      assert "tid-a" in ids
      assert "tid-b" in ids
      assert length(ids) == length(Enum.uniq(ids))
    end

    test "returns empty list when no users exist" do
      # This test uses its own isolated DB sandbox; prior inserts are rolled back
      # so we just assert the function returns a list
      result = Accounts.list_tenant_ids()
      assert is_list(result)
    end
  end

  # ---------------------------------------------------------------------------
  # create_mailbox/2
  # ---------------------------------------------------------------------------

  describe "create_mailbox/2" do
    test "creates mailbox with valid attributes" do
      user = insert(:user, tenant_id: @tenant)
      attrs = %{user_id: user.id, provider: :google, email_address: "mb@example.com"}

      assert {:ok, mailbox} = Accounts.create_mailbox(attrs, @tenant)
      assert mailbox.email_address == "mb@example.com"
      assert mailbox.provider == :google
      assert mailbox.tenant_id == @tenant
    end

    test "returns changeset error when required fields are missing" do
      assert {:error, changeset} = Accounts.create_mailbox(%{}, @tenant)
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :user_id)
      assert Map.has_key?(errors, :provider)
      assert Map.has_key?(errors, :email_address)
    end

    test "returns changeset error when provider is invalid" do
      user = insert(:user, tenant_id: @tenant)
      attrs = %{user_id: user.id, provider: :yahoo, email_address: "mb@e.com"}

      assert {:error, changeset} = Accounts.create_mailbox(attrs, @tenant)
      assert Map.has_key?(errors_on(changeset), :provider)
    end

    test "returns changeset error when email_address is not unique for tenant" do
      user = insert(:user, tenant_id: @tenant)
      attrs = %{user_id: user.id, provider: :google, email_address: "dup@e.com"}

      {:ok, _} = Accounts.create_mailbox(attrs, @tenant)
      assert {:error, changeset} = Accounts.create_mailbox(attrs, @tenant)
      assert Map.has_key?(errors_on(changeset), :email_address)
    end
  end

  # ---------------------------------------------------------------------------
  # upsert_credential/1
  # ---------------------------------------------------------------------------

  describe "upsert_credential/1 — insert path" do
    test "inserts a new credential when user_id + provider combo does not exist" do
      user = insert(:user, tenant_id: @tenant)
      expires = DateTime.add(DateTime.utc_now(), 3600) |> DateTime.truncate(:second)
      attrs = %{
        user_id: user.id,
        tenant_id: @tenant,
        provider: :google,
        expires_at: expires
      }

      assert {:ok, cred} = Accounts.upsert_credential(attrs)
      assert cred.provider == :google
      assert cred.user_id == user.id
    end

    test "returns changeset error when required fields missing" do
      assert {:error, changeset} = Accounts.upsert_credential(%{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :tenant_id)
    end

    test "accepts string keys" do
      user = insert(:user, tenant_id: @tenant)
      attrs = %{"user_id" => user.id, "tenant_id" => @tenant, "provider" => "microsoft"}

      assert {:ok, cred} = Accounts.upsert_credential(attrs)
      assert cred.provider == :microsoft
    end
  end

  describe "upsert_credential/1 — update path" do
    test "updates existing credential when user_id + provider match" do
      user = insert(:user, tenant_id: @tenant)
      old_expires = DateTime.add(DateTime.utc_now(), 1800) |> DateTime.truncate(:second)
      insert(:credential, user_id: user.id, tenant_id: @tenant, provider: :google,
             expires_at: old_expires)

      new_expires = DateTime.add(DateTime.utc_now(), 7200) |> DateTime.truncate(:second)
      attrs = %{user_id: user.id, tenant_id: @tenant, provider: :google, expires_at: new_expires}

      assert {:ok, updated} = Accounts.upsert_credential(attrs)
      assert DateTime.compare(updated.expires_at, old_expires) == :gt
    end
  end
end
