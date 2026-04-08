defmodule Kontor.Contacts.RelationshipGraphWorker do
  @moduledoc "Builds contact relationship edges from email co-participation patterns."
  use GenServer
  require Logger

  import Ecto.Query

  @interval_ms 60_000
  @lookback_days 30
  @min_co_occurrences 3
  @decay_factor 0.95

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
    cutoff = DateTime.utc_now() |> DateTime.add(-@lookback_days * 86_400, :second)

    threads =
      Kontor.Repo.all(
        from e in Kontor.Mail.Email,
          where: e.tenant_id == ^tenant_id and e.received_at >= ^cutoff,
          select: e.thread_id,
          distinct: true
      )

    emails_by_thread =
      Kontor.Repo.all(
        from e in Kontor.Mail.Email,
          where: e.tenant_id == ^tenant_id and e.thread_id in ^threads,
          select: %{thread_id: e.thread_id, sender: e.sender, recipients: e.recipients}
      )
      |> Enum.group_by(& &1.thread_id)

    relationship_attrs = build_relationships_from_threads(Map.values(emails_by_thread))

    Enum.each(relationship_attrs, fn %{email_a: email_a, email_b: email_b, count: count} ->
      with contact_a when not is_nil(contact_a) <-
             Kontor.Contacts.get_contact_by_email(email_a, tenant_id),
           contact_b when not is_nil(contact_b) <-
             Kontor.Contacts.get_contact_by_email(email_b, tenant_id) do
        weight = min(count / 10.0, 1.0)

        Kontor.Contacts.upsert_relationship(
          contact_a.id,
          contact_b.id,
          "correspondent",
          %{
            weight: weight,
            evidence_summary: "Co-occurred in #{count} email threads",
            created_by: :llm
          },
          tenant_id
        )
      end
    end)

    decay_existing_relationships(tenant_id)
  rescue
    e -> Logger.warning("RelationshipGraphWorker error: #{inspect(e)}")
  end

  @doc """
  Takes a list of thread email groups (each group is a list of email maps with
  :sender and :recipients keys) and returns a list of relationship attribute maps
  for pairs that co-occur 3 or more times.
  """
  def build_relationships_from_threads(thread_groups) do
    thread_groups
    |> Enum.reduce(%{}, fn emails, acc ->
      participants =
        emails
        |> Enum.flat_map(fn e -> [e.sender | (e.recipients || [])] end)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)

      pairs = for a <- participants, b <- participants, a < b, do: {a, b}

      Enum.reduce(pairs, acc, fn pair, inner_acc ->
        Map.update(inner_acc, pair, 1, &(&1 + 1))
      end)
    end)
    |> Enum.filter(fn {_pair, count} -> count >= @min_co_occurrences end)
    |> Enum.map(fn {{email_a, email_b}, count} ->
      %{email_a: email_a, email_b: email_b, count: count}
    end)
  end

  defp decay_existing_relationships(tenant_id) do
    Kontor.Repo.update_all(
      from(r in Kontor.Contacts.ContactRelationship,
        where: r.tenant_id == ^tenant_id and r.relationship_type == "correspondent"
      ),
      set: [last_updated: DateTime.utc_now() |> DateTime.truncate(:second)],
      inc: []
    )

    Kontor.Repo.all(
      from r in Kontor.Contacts.ContactRelationship,
        where: r.tenant_id == ^tenant_id and r.relationship_type == "correspondent"
    )
    |> Enum.each(fn rel ->
      new_weight = rel.weight * @decay_factor

      rel
      |> Kontor.Contacts.ContactRelationship.changeset(%{
        weight: new_weight,
        last_updated: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Kontor.Repo.update()
    end)
  end

  defp schedule_run do
    Process.send_after(self(), :run, @interval_ms)
  end
end
