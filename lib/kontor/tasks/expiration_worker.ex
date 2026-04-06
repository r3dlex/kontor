defmodule Kontor.Tasks.ExpirationWorker do
  @moduledoc "Marks tasks as expired when their scheduled_action_at has passed."
  use GenServer

  @check_interval_ms 15 * 60 * 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check, state) do
    expire_overdue_tasks()
    schedule_check()
    {:noreply, state}
  end

  defp expire_overdue_tasks do
    import Ecto.Query

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      Kontor.Repo.update_all(
        from(t in Kontor.Tasks.Task,
          where: t.status in [:created, :confirmed]
            and not is_nil(t.scheduled_action_at)
            and t.scheduled_action_at < ^now
        ),
        set: [status: :expired, updated_at: now]
      )

    if count > 0 do
      require Logger
      Logger.info("ExpirationWorker: expired #{count} tasks")
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check, @check_interval_ms)
  end
end
