defmodule KontorWeb.API.V1.SkillController do
  use KontorWeb, :controller

  alias Kontor.AI.Skills

  def index(conn, _params) do
    skills = Skills.list_skills(conn.assigns.tenant_id)
    json(conn, %{skills: Enum.map(skills, &skill_json/1)})
  end

  def show(conn, %{"id" => id}) do
    case Skills.get_skill(id, conn.assigns.tenant_id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      skill -> json(conn, %{skill: skill_json(skill)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant_id

    with skill when not is_nil(skill) <- Skills.get_skill(id, tenant_id),
         {:ok, updated} <- Skills.update_skill(skill, Map.put(params, "author", :user)) do
      json(conn, %{skill: skill_json(updated)})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: cs})
    end
  end

  def versions(conn, %{"id" => id}) do
    tenant_id = conn.assigns.tenant_id
    case Skills.get_skill(id, tenant_id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      _skill ->
        versions = Skills.list_skill_versions(id)
        json(conn, %{versions: Enum.map(versions, &version_json/1)})
    end
  end

  def revert(conn, %{"id" => id, "version_id" => version_id}) do
    tenant_id = conn.assigns.tenant_id
    case Skills.revert_skill(id, version_id, tenant_id) do
      {:ok, skill} -> json(conn, %{skill: skill_json(skill)})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: cs})
    end
  end

  def execute(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant_id
    input = Map.get(params, "input", %{})
    case Skills.get_skill(id, tenant_id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      skill ->
        case Kontor.AI.Pipeline.run_skill(skill.name, input, tenant_id) do
          {:ok, result} -> json(conn, %{result: result})
          {:error, reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
        end
    end
  end

  defp skill_json(s) do
    %{
      id: s.id,
      namespace: s.namespace,
      name: s.name,
      version: s.version,
      content: s.content,
      author: s.author,
      locked: s.locked,
      active: s.active,
      webhook_url: s.webhook_url
    }
  end

  defp version_json(v) do
    %{
      id: v.id,
      version: v.version,
      content: v.content,
      author: v.author,
      inserted_at: v.inserted_at
    }
  end
end
