defmodule Kontor.AI.SkillLoaderTest do
  use Kontor.DataCase, async: false

  alias Kontor.AI.SkillLoader

  # ---------------------------------------------------------------------------
  # load_skill/2
  # ---------------------------------------------------------------------------

  describe "load_skill/2" do
    test "loads an existing shared skill from filesystem" do
      assert {:ok, skill} = SkillLoader.load_skill("classifier", "shared")
      assert is_map(skill.frontmatter)
      assert is_binary(skill.body)
      assert is_binary(skill.raw)
    end

    test "returns {:error, :not_found} for non-existent skill" do
      assert {:error, :not_found} = SkillLoader.load_skill("nonexistent_skill_xyz", "shared")
    end

    test "parses YAML frontmatter correctly for classifier" do
      {:ok, skill} = SkillLoader.load_skill("classifier", "shared")
      assert skill.frontmatter["name"] == "classifier"
      assert skill.frontmatter["trigger"]["tier"] == 1
    end

    test "returns body content as non-empty string" do
      {:ok, skill} = SkillLoader.load_skill("scorer", "shared")
      assert is_binary(skill.body)
      assert String.length(skill.body) > 0
    end

    test "loads all standard shared skills" do
      for name <- ~w(scorer thread_summarizer task_extractor reply_drafter) do
        assert {:ok, _} = SkillLoader.load_skill(name, "shared"),
          "Expected #{name} to be loadable"
      end
    end

    test "returns raw content matching frontmatter + body" do
      {:ok, skill} = SkillLoader.load_skill("classifier", "shared")
      assert String.contains?(skill.raw, "---")
      assert String.contains?(skill.raw, skill.body)
    end

    test "uses default namespace 'shared' when not specified" do
      assert {:ok, skill1} = SkillLoader.load_skill("classifier")
      assert {:ok, skill2} = SkillLoader.load_skill("classifier", "shared")
      assert skill1.raw == skill2.raw
    end

    test "returns {:error, :not_found} for non-existent namespace" do
      assert {:error, :not_found} = SkillLoader.load_skill("classifier", "tenant-that-does-not-exist")
    end
  end

  # ---------------------------------------------------------------------------
  # sync_skill_to_fs/1
  # ---------------------------------------------------------------------------

  describe "sync_skill_to_fs/1" do
    test "writes skill content to filesystem and is then loadable" do
      unique_name = "test_sync_skill_#{System.unique_integer([:positive])}"

      skill = insert(:skill,
        name: unique_name,
        namespace: "shared",
        content: "---\nname: #{unique_name}\nnamespace: shared\nversion: 1\nauthor: system\n---\n# Test\nDo test things.\n"
      )

      SkillLoader.sync_skill_to_fs(skill)

      # Give the async cast a moment to complete
      Process.sleep(50)

      assert {:ok, loaded} = SkillLoader.load_skill(skill.name, "shared")
      assert loaded.frontmatter["name"] == unique_name
    end

    test "overwrites existing file with updated content" do
      unique_name = "test_overwrite_skill_#{System.unique_integer([:positive])}"

      skill = insert(:skill,
        name: unique_name,
        namespace: "shared",
        content: "---\nname: #{unique_name}\nnamespace: shared\nversion: 1\nauthor: system\n---\n# Original\n"
      )

      SkillLoader.sync_skill_to_fs(skill)
      Process.sleep(50)

      updated_skill = %{skill | content: "---\nname: #{unique_name}\nnamespace: shared\nversion: 2\nauthor: system\n---\n# Updated\n"}
      SkillLoader.sync_skill_to_fs(updated_skill)
      Process.sleep(50)

      {:ok, loaded} = SkillLoader.load_skill(skill.name, "shared")
      assert String.contains?(loaded.body, "Updated")
    end
  end
end
