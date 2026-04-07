defmodule Kontor.AI.Pipeline do
  @moduledoc """
  Two-tier email processing pipeline.

  Tier 1 (Classifier): subject + sender + recipients only — minimal token cost.
  Tier 2 (Specialized Skills): lazy-loaded, only classifier-selected skills run.
  Each skill receives the context depth the classifier prescribed.

  After each Tier 2 skill runs, the result is post-processed (tasks created,
  thread markdown updated, scores applied) and n8n webhooks are fired if
  the skill defines a webhook URL in its YAML frontmatter.
  """

  use GenServer
  require Logger

  alias Kontor.AI.{SkillLoader, MinimaxClient}
  alias Kontor.Repo

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  # Called from poller with tenant_id already on the email struct
  def process_email(%{tenant_id: tenant_id} = email, opts \\ []) do
    GenServer.cast(__MODULE__, {:process_email, email, tenant_id, opts})
  end

  def run_skill(skill_name, input, tenant_id) do
    case SkillLoader.load_skill(skill_name, "shared") do
      {:ok, skill} ->
        prompt = build_prompt(skill, input)
        case MinimaxClient.complete(prompt, tenant_id) do
          {:ok, result} ->
            fire_webhook(skill, result, tenant_id)
            {:ok, result}
          error -> error
        end
      {:error, _} -> {:error, :skill_not_found}
    end
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:process_email, email, tenant_id, opts}, state) do
    Task.start(fn -> do_process(email, tenant_id, opts) end)
    {:noreply, state}
  end

  defp do_process(email, tenant_id, opts \\ []) do
    with {:ok, tier1} <- run_classifier(email, tenant_id),
         {:ok, tier2} <- run_tier2(email, tier1, tenant_id, opts) do
      post_process(email, tier1, tier2, tenant_id)
      {:ok, %{tier1: tier1, tier2: tier2, email_id: email.id}}
    end
  end

  defp run_classifier(email, tenant_id) do
    case SkillLoader.load_skill("classifier", "shared") do
      {:ok, skill} ->
        input = %{subject: email.subject, sender: email.sender, recipients: email.recipients}
        cache_key = "t1:#{email.tenant_id}:#{email.message_id}"
        MinimaxClient.complete(build_prompt(skill, input), tenant_id, cache_key: cache_key)

      {:error, _} ->
        Logger.warning("Pipeline: classifier not found, using passthrough")
        {:ok, %{
          "tier2_skills" => ["scorer", "thread_summarizer"],
          "urgency_estimate" => 0.5,
          "category" => "unknown",
          "context_depth" => "full_body"
        }}
    end
  end

  defp run_tier2(email, tier1, tenant_id, opts \\ []) do
    cutoff_months = Keyword.get(opts, :task_age_cutoff_months, 3)
    cutoff_dt = DateTime.add(DateTime.utc_now(), -cutoff_months * 30 * 24 * 3600, :second)
    skill_names = if email.received_at && DateTime.compare(email.received_at, cutoff_dt) == :lt do
      tier1["tier2_skills"] |> Enum.reject(&(&1 == "task_extractor"))
    else
      tier1["tier2_skills"]
    end
    context_depth = Map.get(tier1, "context_depth", "full_body")

    results =
      skill_names
      |> Enum.map(fn name ->
        {name, Task.async(fn -> run_one_tier2(name, email, context_depth, tenant_id) end)}
      end)
      |> Enum.map(fn {name, task} -> {name, Task.await(task, 60_000)} end)
      |> Enum.filter(fn {_name, result} -> match?({:ok, _}, result) end)
      |> Map.new(fn {name, {:ok, result}} -> {name, result} end)

    {:ok, results}
  end

  defp run_one_tier2(name, email, context_depth, tenant_id) do
    namespace = "shared"

    case SkillLoader.load_skill(name, namespace) do
      {:ok, skill} ->
        input = build_email_input(email, context_depth)
        case MinimaxClient.complete(build_prompt(skill, input), tenant_id) do
          {:ok, result} ->
            fire_webhook(skill, result, tenant_id)
            {:ok, result}
          error -> error
        end

      {:error, _} ->
        Logger.warning("Pipeline: tier2 skill #{name} not found")
        {:error, :not_found}
    end
  end

  # Post-process tier2 results: persist tasks, thread markdown, scores
  defp post_process(email, _tier1, tier2, tenant_id) do
    try do
      # Thread summarizer → update thread markdown
      if summary = Map.get(tier2, "thread_summarizer") do
        if md = Map.get(summary, "updated_thread_markdown") do
          Kontor.AI.Sandbox.execute(
            :write_thread_markdown,
            %{thread_id: email.thread_id, content: md},
            tenant_id
          )
        end
      end

      # Scorer → update thread scores
      if scores = Map.get(tier2, "scorer") do
        Kontor.AI.Sandbox.execute(
          :update_score,
          %{thread_id: email.thread_id, scores: atomize_keys(scores)},
          tenant_id
        )
      end

      # Task extractor → create tasks
      if tasks_result = Map.get(tier2, "task_extractor") do
        tasks = if is_list(tasks_result), do: tasks_result, else: Map.get(tasks_result, "tasks", [])
        Enum.each(tasks, fn task_attrs ->
          attrs =
            atomize_keys(task_attrs)
            |> Map.merge(%{thread_id: email.thread_id, email_id: email.id})

          Kontor.AI.Sandbox.execute(:create_task, attrs, tenant_id)
        end)
      end

      # Reply drafter → store draft content in task if it exists
      if _draft = Map.get(tier2, "reply_drafter"), do: :ok

      # Contact organizer → run in background
      if _contact = Map.get(tier2, "contact_organizer"), do: :ok

      # Atomic CAS: mark thread as processed (process-once guarantee)
      # Skip CAS if thread_id is nil (Ecto forbids == nil in queries)
      case (if is_nil(email.thread_id), do: {:ok, :already_processed}, else: Kontor.Mail.mark_thread_processed(email.thread_id, tenant_id)) do
        {:ok, :updated} ->
          # Won the race — conditionally nil out body based on mailbox.copy_emails
          email_with_mailbox = Repo.preload(email, :mailbox)
          if email_with_mailbox.mailbox && !email_with_mailbox.mailbox.copy_emails do
            Kontor.Mail.clear_email_body(email_with_mailbox)
          end

        {:ok, :already_processed} ->
          # Another process won — skip body cleanup
          :ok
      end
    rescue
      e ->
        Logger.error("Pipeline post_process failed for email #{email.id}: #{inspect(e)}")
        # Body remains intact; markdown_stale stays true for MarkdownBackfillWorker retry
        :ok
    end
  end

  defp fire_webhook(%{frontmatter: %{"webhook" => url}}, result, _tenant_id) when is_binary(url) and url != "" do
    Task.start(fn ->
      case Req.post(url, json: %{result: result, source: "kontor"}) do
        {:ok, _} -> :ok
        {:error, reason} -> Logger.warning("Webhook POST to #{url} failed: #{inspect(reason)}")
      end
    end)
  end
  defp fire_webhook(_skill, _result, _tenant_id), do: :ok

  defp build_email_input(email, "headers_only") do
    %{
      subject: email.subject,
      sender: email.sender,
      recipients: email.recipients,
      prior_thread_samples: fetch_prior_thread_samples(email)
    }
  end

  defp build_email_input(email, "first_100_chars") do
    %{
      subject: email.subject,
      sender: email.sender,
      recipients: email.recipients,
      body_preview: String.slice(email.body || "", 0, 100),
      prior_thread_samples: fetch_prior_thread_samples(email)
    }
  end

  defp build_email_input(email, _full) do
    %{
      subject: email.subject,
      sender: email.sender,
      recipients: email.recipients,
      body: email.body,
      prior_thread_samples: fetch_prior_thread_samples(email)
    }
  end

  defp fetch_prior_thread_samples(email) do
    Kontor.Mail.sample_thread_emails(email.thread_id, email.tenant_id, 3)
    |> Enum.filter(fn e -> e.id != email.id end)
    |> Enum.map(fn e ->
      %{
        subject: e.subject,
        sender: e.sender,
        body_preview: String.slice(e.body || "", 0, 200)
      }
    end)
  end

  defp build_prompt(%{body: template, frontmatter: fm}, input) do
    output_schema = fm["output_schema"] || []

    """
    #{template}

    ## Input

    ```json
    #{Jason.encode!(input, pretty: true)}
    ```

    ## Required Output

    Respond with valid JSON containing these fields: #{Enum.join(output_schema, ", ")}
    """
  end

  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn
      {k, v}, acc when is_binary(k) ->
        try do
          Map.put(acc, String.to_existing_atom(k), v)
        rescue
          ArgumentError -> acc
        end
      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end
  defp atomize_keys(other), do: other
end
