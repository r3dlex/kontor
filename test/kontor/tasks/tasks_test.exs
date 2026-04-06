defmodule Kontor.TasksTest do
  use Kontor.DataCase, async: true

  alias Kontor.Tasks
  alias Kontor.Tasks.Task

  @tenant "tenant-tasks-test"
  @auto_confirm_threshold 0.85

  # ---------------------------------------------------------------------------
  # list_tasks/2
  # ---------------------------------------------------------------------------

  describe "list_tasks/2" do
    test "returns all tasks for tenant ordered by importance descending" do
      insert(:task, tenant_id: @tenant, title: "Low importance", importance: 0.1)
      insert(:task, tenant_id: @tenant, title: "High importance", importance: 0.9)
      insert(:task, tenant_id: @tenant, title: "Mid importance", importance: 0.5)

      tasks = Tasks.list_tasks(@tenant)

      assert length(tasks) == 3
      importances = Enum.map(tasks, & &1.importance)
      assert importances == Enum.sort(importances, :desc)
    end

    test "returns empty list when no tasks exist for tenant" do
      assert Tasks.list_tasks(@tenant) == []
    end

    test "does not return tasks belonging to another tenant" do
      insert(:task, tenant_id: "other-tenant", title: "Other tenant task")

      assert Tasks.list_tasks(@tenant) == []
    end

    test "filters tasks by status when status option provided" do
      insert(:task, tenant_id: @tenant, status: :confirmed)
      insert(:task, tenant_id: @tenant, status: :created)
      insert(:task, tenant_id: @tenant, status: :done)

      confirmed = Tasks.list_tasks(@tenant, status: "confirmed")

      assert length(confirmed) == 1
      assert hd(confirmed).status == :confirmed
    end

    test "returns all tasks when status option is nil" do
      insert(:task, tenant_id: @tenant, status: :confirmed)
      insert(:task, tenant_id: @tenant, status: :created)

      tasks = Tasks.list_tasks(@tenant, status: nil)

      assert length(tasks) == 2
    end

    test "returns empty list when status filter matches no tasks" do
      insert(:task, tenant_id: @tenant, status: :created)

      assert Tasks.list_tasks(@tenant, status: "done") == []
    end
  end

  # ---------------------------------------------------------------------------
  # get_task/2
  # ---------------------------------------------------------------------------

  describe "get_task/2" do
    test "returns task when id and tenant_id match" do
      task = insert(:task, tenant_id: @tenant)

      result = Tasks.get_task(task.id, @tenant)

      assert result.id == task.id
      assert result.tenant_id == @tenant
    end

    test "returns nil when task id does not exist" do
      assert Tasks.get_task(Ecto.UUID.generate(), @tenant) == nil
    end

    test "returns nil when task belongs to different tenant" do
      task = insert(:task, tenant_id: "other-tenant")

      assert Tasks.get_task(task.id, @tenant) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # create_task/2
  # ---------------------------------------------------------------------------

  describe "create_task/2" do
    test "creates task with valid attributes" do
      attrs = %{task_type: :reply, title: "Reply to Bob", confidence: 0.6}

      assert {:ok, task} = Tasks.create_task(attrs, @tenant)
      assert task.title == "Reply to Bob"
      assert task.task_type == :reply
      assert task.tenant_id == @tenant
      assert task.status == :created
    end

    test "sets tenant_id from argument, ignoring any tenant_id in attrs" do
      attrs = %{task_type: :custom, title: "My Task", tenant_id: "injected-tenant"}

      assert {:ok, task} = Tasks.create_task(attrs, @tenant)
      assert task.tenant_id == @tenant
    end

    test "returns changeset error when required fields are missing" do
      assert {:error, changeset} = Tasks.create_task(%{}, @tenant)

      errors = errors_on(changeset)
      assert Map.has_key?(errors, :task_type)
      assert Map.has_key?(errors, :title)
    end

    test "returns changeset error when confidence is out of range" do
      attrs = %{task_type: :reply, title: "Task", confidence: 1.5}

      assert {:error, changeset} = Tasks.create_task(attrs, @tenant)
      assert Map.has_key?(errors_on(changeset), :confidence)
    end

    test "auto-confirms task when confidence is at the high threshold" do
      attrs = %{task_type: :reply, title: "High confidence task", confidence: @auto_confirm_threshold}

      assert {:ok, task} = Tasks.create_task(attrs, @tenant)
      assert task.status == :confirmed
    end

    test "auto-confirms task when confidence exceeds the high threshold" do
      attrs = %{task_type: :reply, title: "Very high confidence", confidence: 0.95}

      assert {:ok, task} = Tasks.create_task(attrs, @tenant)
      assert task.status == :confirmed
    end

    test "does not auto-confirm task when confidence is below the high threshold" do
      attrs = %{task_type: :reply, title: "Low confidence task", confidence: 0.6}

      assert {:ok, task} = Tasks.create_task(attrs, @tenant)
      assert task.status == :created
    end

    test "does not auto-confirm task when confidence is just below the threshold" do
      attrs = %{task_type: :reply, title: "Near threshold task", confidence: 0.84}

      assert {:ok, task} = Tasks.create_task(attrs, @tenant)
      assert task.status == :created
    end

    test "creates task with zero confidence without auto-confirming" do
      attrs = %{task_type: :custom, title: "Zero confidence", confidence: 0.0}

      assert {:ok, task} = Tasks.create_task(attrs, @tenant)
      assert task.status == :created
    end

    test "accepts string keys in attrs via atomize" do
      attrs = %{"task_type" => "reply", "title" => "String key task", "confidence" => 0.5}

      assert {:ok, task} = Tasks.create_task(attrs, @tenant)
      assert task.title == "String key task"
    end

    test "persists task to the database" do
      attrs = %{task_type: :reply, title: "Persisted task"}

      assert {:ok, task} = Tasks.create_task(attrs, @tenant)
      assert Tasks.get_task(task.id, @tenant) != nil
    end
  end

  # ---------------------------------------------------------------------------
  # update_task/3
  # ---------------------------------------------------------------------------

  describe "update_task/3" do
    test "updates task when found" do
      task = insert(:task, tenant_id: @tenant, status: :created)

      assert {:ok, updated} = Tasks.update_task(task.id, %{status: :confirmed}, @tenant)
      assert updated.status == :confirmed
    end

    test "returns not_found error when task id does not exist" do
      assert {:error, :not_found} = Tasks.update_task(Ecto.UUID.generate(), %{status: :done}, @tenant)
    end

    test "returns not_found error when task belongs to different tenant" do
      task = insert(:task, tenant_id: "other-tenant")

      assert {:error, :not_found} = Tasks.update_task(task.id, %{status: :done}, @tenant)
    end

    test "returns changeset error for invalid update attributes" do
      task = insert(:task, tenant_id: @tenant)

      assert {:error, changeset} = Tasks.update_task(task.id, %{confidence: 2.0}, @tenant)
      assert Map.has_key?(errors_on(changeset), :confidence)
    end

    test "accepts string keys in attrs" do
      task = insert(:task, tenant_id: @tenant)

      assert {:ok, updated} = Tasks.update_task(task.id, %{"status" => "done"}, @tenant)
      assert updated.status == :done
    end

    test "can update title" do
      task = insert(:task, tenant_id: @tenant, title: "Original title")

      assert {:ok, updated} = Tasks.update_task(task.id, %{title: "New title"}, @tenant)
      assert updated.title == "New title"
    end
  end

  # ---------------------------------------------------------------------------
  # maybe_auto_confirm via create_task (private function tested through public API)
  # ---------------------------------------------------------------------------

  describe "maybe_auto_confirm threshold behavior" do
    test "status remains :created when confidence is 0.84 (below threshold)" do
      {:ok, task} = Tasks.create_task(%{task_type: :reply, title: "T", confidence: 0.84}, @tenant)
      assert task.status == :created
    end

    test "status becomes :confirmed when confidence is exactly 0.85 (at threshold)" do
      {:ok, task} = Tasks.create_task(%{task_type: :reply, title: "T", confidence: 0.85}, @tenant)
      assert task.status == :confirmed
    end

    test "status becomes :confirmed when confidence is 0.86 (above threshold)" do
      {:ok, task} = Tasks.create_task(%{task_type: :reply, title: "T", confidence: 0.86}, @tenant)
      assert task.status == :confirmed
    end

    test "status remains :created when no confidence provided (defaults to 0.0)" do
      {:ok, task} = Tasks.create_task(%{task_type: :reply, title: "T"}, @tenant)
      assert task.status == :created
    end
  end
end
