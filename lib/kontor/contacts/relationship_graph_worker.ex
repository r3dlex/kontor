defmodule Kontor.Contacts.RelationshipGraphWorker do
  @moduledoc "Builds contact relationship edges from email co-participation patterns."
  use GenServer
  require Logger

  @interval_ms 60_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_run()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:run, state) do
    build_relationships()
    schedule_run()
    {:noreply, state}
  end

  defp build_relationships do
    tenant_ids = Kontor.Accounts.list_tenant_ids()
    Enum.each(tenant_ids, &build_tenant_relationships/1)
  end

  defp build_tenant_relationships(tenant_id) do
    import Ecto.Query
    emails = Kontor.Repo.all(
      from e in Kontor.Mail.Email,
      where: e.tenant_id == ^tenant_id,
      order_by: [desc: :received_at],
      limit: 500
    )

    Enum.each(emails, fn email ->
      participants = [email.sender | (email.recipients || [])]
      pairs = for a <- participants, b <- participants, a < b, do: {a, b}

      Enum.each(pairs, fn {a, b} ->
        with contact_a when not is_nil(contact_a) <- Kontor.Contacts.get_contact_by_email(a, tenant_id),
             contact_b when not is_nil(contact_b) <- Kontor.Contacts.get_contact_by_email(b, tenant_id) do
          Kontor.Contacts.upsert_relationship(
            contact_a.id, contact_b.id, "co_participant",
            %{weight: 0.1, evidence_summary: "Appeared in same email thread", created_by: :llm},
            tenant_id
          )
        end
      end)
    end)
  rescue
    e -> Logger.warning("RelationshipGraphWorker error: #{inspect(e)}")
  end

  defp schedule_run do
    Process.send_after(self(), :run, @interval_ms)
  end
end
