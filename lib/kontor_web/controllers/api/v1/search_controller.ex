defmodule KontorWeb.API.V1.SearchController do
  use KontorWeb, :controller

  def index(conn, %{"q" => query} = params) when is_binary(query) and byte_size(query) > 0 do
    tenant_id = conn.assigns.tenant_id
    limit = params |> Map.get("limit", "10") |> parse_limit()

    case Kontor.Search.semantic_search(query, tenant_id, limit: limit) do
      {:ok, results} ->
        json(conn, %{
          results: Enum.map(results, fn r ->
            %{
              id: r.thread_id,
              subject: r.thread_subject,
              similarity_score: r.similarity_score,
              type: "thread"
            }
          end)
        })

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "search unavailable"})
    end
  end

  def index(conn, _params) do
    json(conn, %{results: []})
  end

  defp parse_limit(str) do
    case Integer.parse(str) do
      {n, ""} when n > 0 and n <= 100 -> n
      _ -> 10
    end
  end
end
