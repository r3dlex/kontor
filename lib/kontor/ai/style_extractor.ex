defmodule Kontor.AI.StyleExtractor do
  @moduledoc """
  Oban worker that analyzes a user's sent emails to extract writing style
  and populates the corresponding StyleProfile.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  import Ecto.Query

  alias Kontor.Repo
  alias Kontor.Mail.Email
  alias Kontor.Accounts.User
  alias Kontor.AI.{MinimaxClient, Skills, StyleProfile}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "tenant_id" => tenant_id}}) do
    with {:ok, user} <- fetch_user(user_id, tenant_id),
         emails when emails != [] <- fetch_sent_emails(user.email, tenant_id),
         {:ok, content} <- extract_style(emails, tenant_id) do
      upsert_style_profile(content, tenant_id)
    else
      [] ->
        Logger.info("StyleExtractor: no sent emails found for user #{user_id}, skipping")
        :ok

      {:error, :user_not_found} ->
        Logger.warning("StyleExtractor: user #{user_id} not found in tenant #{tenant_id}")
        {:error, :user_not_found}

      {:error, :llm_unavailable} ->
        Logger.warning("StyleExtractor: LLM unavailable, skipping style extraction for user #{user_id}")
        :ok

      {:error, reason} ->
        Logger.error("StyleExtractor: failed for user #{user_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def enqueue(user_id, tenant_id) do
    %{"user_id" => user_id, "tenant_id" => tenant_id}
    |> new()
    |> Oban.insert()
  end

  defp fetch_user(user_id, tenant_id) do
    case Repo.get_by(User, id: user_id, tenant_id: tenant_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp fetch_sent_emails(user_email, tenant_id) do
    Repo.all(
      from e in Email,
        where: e.tenant_id == ^tenant_id and e.sender == ^user_email,
        order_by: [desc: e.received_at],
        limit: 20,
        select: %{subject: e.subject, body: e.body}
    )
  end

  defp extract_style(emails, tenant_id) do
    prompt = build_extraction_prompt(emails)

    case MinimaxClient.complete(prompt, tenant_id) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        Logger.warning("StyleExtractor: LLM call failed: #{inspect(reason)}")
        {:error, :llm_unavailable}
    end
  end

  defp build_extraction_prompt(emails) do
    samples =
      emails
      |> Enum.map_join("\n\n---\n\n", fn %{subject: subject, body: body} ->
        "Subject: #{subject}\n\n#{body}"
      end)

    """
    Analyze the following email samples written by a single person and extract their writing style.

    ## Email Samples

    #{samples}

    ## Instructions

    Identify and describe the following style attributes:
    - **Tone**: Is the writing formal, semi-formal, or casual?
    - **Greeting**: What greeting phrases do they typically use (e.g. "Hi", "Hello", "Dear")?
    - **Sign-off**: What closing phrases do they typically use (e.g. "Best", "Regards", "Thanks")?
    - **Sentence length**: Do they prefer short, punchy sentences or longer, complex ones?
    - **Bullet points**: Do they frequently use bullet points or numbered lists?
    - **Emoji usage**: Do they use emojis, and if so, how often?
    - **Overall style summary**: A short paragraph describing their writing voice.

    Respond with a plain text style guide that could be given to an AI to mimic this person's writing style.
    """
  end

  defp upsert_style_profile(content, tenant_id) when is_binary(content) do
    attrs = %{
      "tenant_id" => tenant_id,
      "name" => "auto_extracted",
      "content" => content
    }

    case Skills.create_style_profile(attrs, tenant_id) do
      {:ok, _profile} ->
        Logger.info("StyleExtractor: created style profile for tenant #{tenant_id}")
        :ok

      {:error, changeset} ->
        if unique_constraint_error?(changeset) do
          update_existing_style_profile(content, tenant_id)
        else
          Logger.error("StyleExtractor: failed to upsert style profile: #{inspect(changeset.errors)}")
          {:error, :profile_upsert_failed}
        end
    end
  end

  defp upsert_style_profile(content, tenant_id) when is_map(content) do
    text = Map.get(content, "content") || Map.get(content, :content) || inspect(content)
    upsert_style_profile(text, tenant_id)
  end

  defp unique_constraint_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {_msg, opts}} ->
      Keyword.get(opts, :constraint) == :unique
    end)
  end

  defp update_existing_style_profile(content, tenant_id) do
    case Repo.get_by(StyleProfile, tenant_id: tenant_id, name: "auto_extracted") do
      nil ->
        :ok

      profile ->
        profile
        |> StyleProfile.changeset(%{"content" => content})
        |> Repo.update()
        |> case do
          {:ok, _} ->
            Logger.info("StyleExtractor: updated style profile for tenant #{tenant_id}")
            :ok

          {:error, reason} ->
            Logger.error("StyleExtractor: failed to update style profile: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end
end
