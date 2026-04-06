defmodule Kontor.AI.SkillsTest do
  use Kontor.DataCase, async: false

  alias Kontor.AI.Skills

  @tenant "tenant-skills-test"

  # ---------------------------------------------------------------------------
  # list_skills/1
  # ---------------------------------------------------------------------------

  describe "list_skills/1" do
    test "returns active skills for tenant" do
      skill = insert(:skill, tenant_id: @tenant, active: true)
      _inactive = insert(:skill, tenant_id: @tenant, active: false)

      skills = Skills.list_skills(@tenant)
      ids = Enum.map(skills, & &1.id)
      assert skill.id in ids
    end

    test "does not include inactive skills" do
      inactive = insert(:skill, tenant_id: @tenant, active: false)

      skills = Skills.list_skills(@tenant)
      ids = Enum.map(skills, & &1.id)
      refute inactive.id in ids
    end

    test "does not return skills from other tenants" do
      insert(:skill, tenant_id: "other-tenant-skills-#{System.unique_integer([:positive])}", active: true)

      # Only look at skills we inserted — filter by tenant
      skills = Skills.list_skills(@tenant)
      for s <- skills do
        assert s.tenant_id == @tenant
      end
    end

    test "returns skills ordered by namespace then name" do
      s1 = insert(:skill, tenant_id: @tenant, namespace: "shared", name: "zzz_skill_#{System.unique_integer([:positive])}", active: true)
      s2 = insert(:skill, tenant_id: @tenant, namespace: "shared", name: "aaa_skill_#{System.unique_integer([:positive])}", active: true)

      skills = Skills.list_skills(@tenant)
      names = Enum.map(skills, & &1.name)
      assert Enum.find_index(names, &(&1 == s2.name)) < Enum.find_index(names, &(&1 == s1.name))
    end

    test "returns empty list when tenant has no active skills" do
      tenant = "tenant-no-skills-#{System.unique_integer([:positive])}"
      assert Skills.list_skills(tenant) == []
    end
  end

  # ---------------------------------------------------------------------------
  # get_skill/2
  # ---------------------------------------------------------------------------

  describe "get_skill/2" do
    test "returns skill for correct tenant" do
      skill = insert(:skill, tenant_id: @tenant)
      assert %{id: id} = Skills.get_skill(skill.id, @tenant)
      assert id == skill.id
    end

    test "returns nil for wrong tenant" do
      skill = insert(:skill, tenant_id: "other-tenant-get-#{System.unique_integer([:positive])}")
      assert nil == Skills.get_skill(skill.id, @tenant)
    end

    test "returns nil for non-existent id" do
      assert nil == Skills.get_skill(Ecto.UUID.generate(), @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # create_skill/2
  # ---------------------------------------------------------------------------

  describe "create_skill/2" do
    test "creates a skill with tenant_id" do
      name = "my_skill_#{System.unique_integer([:positive])}"
      attrs = %{name: name, namespace: "shared", content: "---\nname: #{name}\n---\n# Body", version: 1, author: :system}
      assert {:ok, skill} = Skills.create_skill(attrs, @tenant)
      assert skill.tenant_id == @tenant
      assert skill.name == name

      # Cleanup filesystem
      File.rm("priv/skills/shared/#{name}.md")
    end

    test "returns error changeset for invalid data (missing required fields)" do
      assert {:error, %Ecto.Changeset{}} = Skills.create_skill(%{}, @tenant)
    end

    test "returns error changeset for missing name" do
      assert {:error, changeset} = Skills.create_skill(%{namespace: "shared", content: "body"}, @tenant)
      assert %{name: [_|_]} = errors_on(changeset)
    end

    test "returns error changeset for missing content" do
      assert {:error, changeset} = Skills.create_skill(%{namespace: "shared", name: "test"}, @tenant)
      assert %{content: [_|_]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # update_skill/2
  # ---------------------------------------------------------------------------

  describe "update_skill/2" do
    test "increments version on update" do
      skill = insert(:skill, tenant_id: @tenant, version: 1)
      assert {:ok, updated} = Skills.update_skill(skill, %{content: "new content"})
      assert updated.version == 2
    end

    test "saves a skill_version record on update" do
      skill = insert(:skill, tenant_id: @tenant, version: 3)
      Skills.update_skill(skill, %{content: "changed"})

      count = Kontor.Repo.one(
        from sv in Kontor.AI.SkillVersion,
        where: sv.skill_id == ^skill.id,
        select: count()
      )
      assert count >= 1
    end

    test "locks skill when author is :user" do
      skill = insert(:skill, tenant_id: @tenant, locked: false)
      assert {:ok, updated} = Skills.update_skill(skill, %{author: :user, content: "user edit"})
      assert updated.locked == true
    end

    test "does not lock when author is :llm" do
      skill = insert(:skill, tenant_id: @tenant, locked: false)
      assert {:ok, updated} = Skills.update_skill(skill, %{author: :llm, content: "llm edit"})
      assert updated.locked == false
    end

    test "does not lock when author is :system" do
      skill = insert(:skill, tenant_id: @tenant, locked: false)
      assert {:ok, updated} = Skills.update_skill(skill, %{author: :system, content: "system edit"})
      assert updated.locked == false
    end

    test "updates content" do
      skill = insert(:skill, tenant_id: @tenant, content: "original")
      assert {:ok, updated} = Skills.update_skill(skill, %{content: "updated content"})
      assert updated.content == "updated content"
    end
  end

  # ---------------------------------------------------------------------------
  # manage/2
  # ---------------------------------------------------------------------------

  describe "manage/2 — list action" do
    test "returns skills list for tenant" do
      insert(:skill, tenant_id: @tenant, active: true)
      result = Skills.manage(%{action: :list}, @tenant)
      assert is_list(result)
    end
  end

  describe "manage/2 — update action" do
    test "updates existing skill by id" do
      skill = insert(:skill, tenant_id: @tenant, version: 1)
      result = Skills.manage(%{action: :update, skill_id: skill.id, content: "updated"}, @tenant)
      assert {:ok, updated} = result
      assert updated.version == 2
    end

    test "returns {:error, :not_found} for missing skill" do
      assert {:error, :not_found} = Skills.manage(%{action: :update, skill_id: Ecto.UUID.generate()}, @tenant)
    end

    test "returns {:error, :not_found} for wrong tenant" do
      other_tenant = "other-manage-tenant-#{System.unique_integer([:positive])}"
      skill = insert(:skill, tenant_id: other_tenant)
      assert {:error, :not_found} = Skills.manage(%{action: :update, skill_id: skill.id}, @tenant)
    end
  end

  # ---------------------------------------------------------------------------
  # list_style_profiles/1
  # ---------------------------------------------------------------------------

  describe "list_style_profiles/1" do
    test "returns list (empty or populated)" do
      profiles = Skills.list_style_profiles(@tenant)
      assert is_list(profiles)
    end

    test "returns only profiles for the given tenant" do
      tenant = "tenant-profiles-#{System.unique_integer([:positive])}"
      {:ok, profile} = Skills.create_style_profile(%{name: "p1", content: "Be brief."}, tenant)

      profiles = Skills.list_style_profiles(tenant)
      ids = Enum.map(profiles, & &1.id)
      assert profile.id in ids

      other_profiles = Skills.list_style_profiles("completely-different-tenant")
      other_ids = Enum.map(other_profiles, & &1.id)
      refute profile.id in other_ids
    end
  end

  # ---------------------------------------------------------------------------
  # create_style_profile/2
  # ---------------------------------------------------------------------------

  describe "create_style_profile/2" do
    test "creates a style profile with tenant_id" do
      tenant = "tenant-create-profile-#{System.unique_integer([:positive])}"
      attrs = %{name: "test_profile", content: "Be concise."}
      assert {:ok, profile} = Skills.create_style_profile(attrs, tenant)
      assert profile.tenant_id == tenant
      assert profile.name == "test_profile"
      assert profile.content == "Be concise."
    end

    test "returns error changeset for missing required fields" do
      assert {:error, %Ecto.Changeset{}} = Skills.create_style_profile(%{}, @tenant)
    end

    test "returns error changeset when name is missing" do
      assert {:error, changeset} = Skills.create_style_profile(%{content: "body"}, @tenant)
      assert %{name: [_|_]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # update_style_profile/3
  # ---------------------------------------------------------------------------

  describe "update_style_profile/3" do
    test "updates an existing profile content" do
      tenant = "tenant-update-profile-#{System.unique_integer([:positive])}"
      {:ok, profile} = Skills.create_style_profile(%{name: "update_test", content: "Original"}, tenant)

      assert {:ok, updated} = Skills.update_style_profile(profile.id, %{content: "Updated"}, tenant)
      assert updated.content == "Updated"
    end

    test "returns {:error, :not_found} for non-existent profile" do
      assert {:error, :not_found} = Skills.update_style_profile(Ecto.UUID.generate(), %{}, @tenant)
    end

    test "returns {:error, :not_found} for wrong tenant" do
      tenant = "tenant-update-wrong-#{System.unique_integer([:positive])}"
      {:ok, profile} = Skills.create_style_profile(%{name: "wrong_tenant_test", content: "Content"}, tenant)

      assert {:error, :not_found} = Skills.update_style_profile(profile.id, %{content: "hacked"}, @tenant)
    end

    test "updates name field" do
      tenant = "tenant-update-name-#{System.unique_integer([:positive])}"
      {:ok, profile} = Skills.create_style_profile(%{name: "old_name", content: "Content"}, tenant)

      assert {:ok, updated} = Skills.update_style_profile(profile.id, %{name: "new_name"}, tenant)
      assert updated.name == "new_name"
    end
  end

  # ---------------------------------------------------------------------------
  # get_style_profile/2
  # ---------------------------------------------------------------------------

  describe "get_style_profile/2" do
    test "returns profile for correct tenant" do
      tenant = "tenant-get-profile-#{System.unique_integer([:positive])}"
      {:ok, profile} = Skills.create_style_profile(%{name: "get_test", content: "Content"}, tenant)

      assert %{id: id} = Skills.get_style_profile(profile.id, tenant)
      assert id == profile.id
    end

    test "returns nil for wrong tenant" do
      tenant = "tenant-get-profile-wrong-#{System.unique_integer([:positive])}"
      {:ok, profile} = Skills.create_style_profile(%{name: "get_wrong", content: "Content"}, tenant)

      assert nil == Skills.get_style_profile(profile.id, "completely-wrong-tenant")
    end

    test "returns nil for non-existent id" do
      assert nil == Skills.get_style_profile(Ecto.UUID.generate(), @tenant)
    end
  end
end
