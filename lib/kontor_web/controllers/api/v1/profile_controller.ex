defmodule KontorWeb.API.V1.ProfileController do
  use KontorWeb, :controller

  alias Kontor.AI.Skills

  def index(conn, _params) do
    profiles = Skills.list_style_profiles(conn.assigns.tenant_id)
    json(conn, %{profiles: Enum.map(profiles, &profile_json/1)})
  end

  def create(conn, params) do
    tenant_id = conn.assigns.tenant_id
    case Kontor.AI.Skills.create_style_profile(params, tenant_id) do
      {:ok, profile} -> conn |> put_status(:created) |> json(%{profile: profile_json(profile)})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant_id

    case Skills.update_style_profile(id, params, tenant_id) do
      {:ok, profile} -> json(conn, %{profile: profile_json(profile)})
      {:error, reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
    end
  end

  defp profile_json(p) do
    %{id: p.id, name: p.name, preserve_voice: p.preserve_voice, auto_select_rules: p.auto_select_rules}
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
