defmodule Kontor.AI.SkillLoaderActiveFlagTest do
  use Kontor.DataCase, async: false
  alias Kontor.AI.SkillLoader

  @test_skill_name "test_inactive_skill_#{:rand.uniform(999_999)}"

  setup do
    skills_path = Application.get_env(:kontor, :skills_path)[:shared] || "priv/skills/shared"
    path = Path.join(skills_path, "#{@test_skill_name}.md")
    content = "---\nname: #{@test_skill_name}\nnamespace: shared\nactive: false\n---\n# Inactive\n"
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    :ok
  end

  describe "load_skill/2 with active: false" do
    test "returns {:error, :not_found} for skill with active: false" do
      assert {:error, :not_found} = SkillLoader.load_skill(@test_skill_name, "shared")
    end
  end
end
