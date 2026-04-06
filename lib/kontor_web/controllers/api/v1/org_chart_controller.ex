defmodule KontorWeb.API.V1.OrgChartController do
  use KontorWeb, :controller

  alias Kontor.Contacts

  def index(conn, _params) do
    charts = Contacts.list_org_charts(conn.assigns.tenant_id)
    json(conn, %{org_charts: Enum.map(charts, &chart_json/1)})
  end

  def create(conn, params) do
    case Contacts.create_org_chart(params, conn.assigns.tenant_id) do
      {:ok, chart} -> conn |> put_status(:created) |> json(%{org_chart: chart_json(chart)})
      {:error, %Ecto.Changeset{} = cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: %{}})
    end
  end

  def update(conn, %{"id" => id} = params) do
    tenant_id = conn.assigns.tenant_id

    with {:ok, _chart} <- Contacts.get_org_chart(id, tenant_id),
         {:ok, updated} <- Contacts.update_org_chart(id, params, tenant_id) do
      json(conn, %{org_chart: chart_json(updated)})
    else
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not found"})
      {:error, %Ecto.Changeset{} = cs} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(cs)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{errors: %{}})
    end
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp chart_json(c) do
    %{id: c.id, name: c.name, source: c.source, structure_json: c.structure_json}
  end
end
