defmodule Kontor.Mail.NewsletterEngagementWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query
  alias Kontor.Repo
  alias Kontor.Mail.NewsletterEngagement

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    auto_archive_count =
      Repo.aggregate(
        from(ne in NewsletterEngagement, where: ne.auto_archive == true),
        :count, :id
      )

    {:ok, %{auto_archive_count: auto_archive_count}}
  end
end
