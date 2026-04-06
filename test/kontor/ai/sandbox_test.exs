defmodule Kontor.AI.SandboxTest do
  use Kontor.DataCase, async: false

  # The Sandbox GenServer is started as part of the application supervision tree.
  # These tests call it directly via its public API.

  alias Kontor.AI.Sandbox

  @tenant "tenant-sandbox-test"

  # ---------------------------------------------------------------------------
  # allowed_actions/0
  # ---------------------------------------------------------------------------

  describe "allowed_actions/0" do
    test "returns a MapSet" do
      assert %MapSet{} = Sandbox.allowed_actions()
    end

    test "includes all documented permitted actions" do
      allowed = Sandbox.allowed_actions()

      expected = [
        :read_email,
        :write_thread_markdown,
        :update_score,
        :draft_reply,
        :create_calendar_entry,
        :update_calendar_entry,
        :manage_skill,
        :create_task,
        :update_task,
        :manage_folder
      ]

      for action <- expected do
        assert MapSet.member?(allowed, action), "Expected #{action} to be in allowed_actions"
      end
    end

    test "contains exactly 10 permitted actions" do
      assert MapSet.size(Sandbox.allowed_actions()) == 10
    end
  end

  # ---------------------------------------------------------------------------
  # execute/4 — action type validation
  # ---------------------------------------------------------------------------

  describe "execute/4 — action type validation" do
    test "rejects an unknown action with :not_permitted" do
      assert {:error, :not_permitted} =
        Sandbox.execute(:send_nuclear_codes, %{}, @tenant)
    end

    test "rejects :delete_all action with :not_permitted" do
      assert {:error, :not_permitted} =
        Sandbox.execute(:delete_all, %{}, @tenant)
    end

    test "rejects :execute_arbitrary_sql with :not_permitted" do
      assert {:error, :not_permitted} =
        Sandbox.execute(:execute_arbitrary_sql, %{query: "DROP TABLE users"}, @tenant)
    end

    test "rejects string action names (only atoms are permitted)" do
      assert {:error, :not_permitted} =
        Sandbox.execute("create_task", %{}, @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # execute/4 — tenant scope validation
  # ---------------------------------------------------------------------------

  describe "execute/4 — tenant scope validation" do
    test "rejects params with a mismatched tenant_id" do
      # :manage_folder is a valid action; the tenant mismatch should stop it
      assert {:error, :tenant_mismatch} =
        Sandbox.execute(:manage_folder, %{tenant_id: "other-tenant"}, @tenant)
    end

    test "permits params with matching tenant_id" do
      # manage_folder delegates and returns {:ok, :delegated}
      assert {:ok, :delegated} =
        Sandbox.execute(:manage_folder, %{tenant_id: @tenant}, @tenant)
    end

    test "permits params with no tenant_id field" do
      assert {:ok, :delegated} =
        Sandbox.execute(:manage_folder, %{}, @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # execute/4 — view context permission validation
  # ---------------------------------------------------------------------------

  describe "execute/4 — view context validation" do
    test "permits action when available_actions is empty (server-side call)" do
      assert {:ok, :delegated} =
        Sandbox.execute(:manage_folder, %{}, @tenant, %{"available_actions" => []})
    end

    test "permits action when no view_context provided (default)" do
      assert {:ok, :delegated} =
        Sandbox.execute(:manage_folder, %{}, @tenant)
    end

    test "permits action when action is listed in available_actions" do
      ctx = %{"available_actions" => ["manage_folder", "create_task"]}

      assert {:ok, :delegated} =
        Sandbox.execute(:manage_folder, %{}, @tenant, ctx)
    end

    test "rejects permitted action when it is not in view available_actions" do
      ctx = %{"available_actions" => ["create_task"]}

      assert {:error, :not_available_in_view} =
        Sandbox.execute(:manage_folder, %{}, @tenant, ctx)
    end
  end

  # ---------------------------------------------------------------------------
  # execute/4 — end-to-end for create_task (uses actual DB via DataCase)
  # ---------------------------------------------------------------------------

  describe "execute/4 — create_task dispatch" do
    test "creates a task when action is :create_task with valid params" do
      params = %{task_type: :reply, title: "Sandbox task", confidence: 0.5}

      assert {:ok, task} = Sandbox.execute(:create_task, params, @tenant)
      assert task.title == "Sandbox task"
      assert task.tenant_id == @tenant
    end

    test "returns changeset error when :create_task params are invalid" do
      assert {:error, changeset} = Sandbox.execute(:create_task, %{}, @tenant)
      assert %Ecto.Changeset{} = changeset
    end
  end

  # ---------------------------------------------------------------------------
  # execute/4 — end-to-end for manage_folder (always returns delegated)
  # ---------------------------------------------------------------------------

  describe "execute/4 — manage_folder dispatch" do
    test "returns {:ok, :delegated} for manage_folder" do
      assert {:ok, :delegated} = Sandbox.execute(:manage_folder, %{}, @tenant)
    end
  end
end
