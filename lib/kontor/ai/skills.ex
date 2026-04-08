defmodule Kontor.AI.Skills do
  @moduledoc "Context module for skill and style profile management."

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.AI.{Skill, SkillVersion, StyleProfile, SkillLoader}

  # --- Skills ---

  def list_skills(tenant_id) do
    Repo.all(from s in Skill,
      where: s.tenant_id == ^tenant_id and s.active == true,
      order_by: [asc: :namespace, asc: :name])
  end

  def get_skill(id, tenant_id) do
    Repo.get_by(Skill, id: id, tenant_id: tenant_id)
  end

  def get_skill_by_name(name, tenant_id) do
    Repo.get_by(Skill, name: name, tenant_id: tenant_id, active: true)
  end

  def create_skill(attrs, tenant_id) do
    attrs = Map.put(attrs, :tenant_id, tenant_id)

    %Skill{}
    |> Skill.changeset(attrs)
    |> Repo.insert()
    |> tap_ok(fn skill ->
      if Application.get_env(:kontor, :skills, [])[:sync_to_fs] != false do
        SkillLoader.sync_skill_to_fs(skill)
        SkillLoader.regenerate_classifier(tenant_id)
      end
    end)
  end

  def update_skill(%Skill{} = skill, attrs) do
    attrs = if Map.get(attrs, :author) == :user or Map.get(attrs, "author") == "user",
      do: Map.put(attrs, :locked, true),
      else: attrs

    old_version = skill

    skill
    |> Skill.changeset(attrs)
    |> Ecto.Changeset.put_change(:version, skill.version + 1)
    |> Repo.update()
    |> tap_ok(fn updated ->
      save_version(old_version)
      if Application.get_env(:kontor, :skills, [])[:sync_to_fs] != false do
        SkillLoader.sync_skill_to_fs(updated)
      end
    end)
  end

  def list_skill_versions(skill_id) do
    Repo.all(
      from v in SkillVersion,
      where: v.skill_id == ^skill_id,
      order_by: [desc: v.version]
    )
  end

  def revert_skill(skill_id, version_id, tenant_id) do
    with skill when not is_nil(skill) <- get_skill(skill_id, tenant_id),
         version when not is_nil(version) <- Repo.get_by(SkillVersion, id: version_id, skill_id: skill_id) do
      update_skill(skill, %{content: version.content, author: :user})
    else
      nil -> {:error, :not_found}
    end
  end

  def manage(%{action: :list}, tenant_id), do: list_skills(tenant_id)

  def manage(%{action: :update, skill_id: id} = params, tenant_id) do
    case get_skill(id, tenant_id) do
      nil -> {:error, :not_found}
      skill -> update_skill(skill, params)
    end
  end

  # --- Style Profiles ---

  def list_style_profiles(tenant_id) do
    Repo.all(from p in StyleProfile, where: p.tenant_id == ^tenant_id)
  end

  def get_style_profile(id, tenant_id) do
    Repo.get_by(StyleProfile, id: id, tenant_id: tenant_id)
  end

  def update_style_profile(id, attrs, tenant_id) do
    case get_style_profile(id, tenant_id) do
      nil -> {:error, :not_found}
      profile ->
        profile
        |> StyleProfile.changeset(attrs)
        |> Repo.update()
    end
  end

  def create_style_profile(attrs, tenant_id) do
    attrs = stringify_keys(attrs) |> Map.put("tenant_id", tenant_id)
    %StyleProfile{}
    |> StyleProfile.changeset(attrs)
    |> Repo.insert()
  end

  defp save_version(%Skill{} = skill) do
    %SkillVersion{}
    |> SkillVersion.changeset(%{
      skill_id: skill.id,
      version: skill.version,
      content: skill.content,
      author: skill.author
    })
    |> Repo.insert()
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp tap_ok({:ok, value} = result, fun), do: (fun.(value); result)
  defp tap_ok(error, _fun), do: error
end
