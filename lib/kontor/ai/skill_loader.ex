defmodule Kontor.AI.SkillLoader do
  @moduledoc """
  Manages the filesystem cache of skill markdown files.
  On boot: syncs all active skills from PostgreSQL to the filesystem.
  On change: updates filesystem when skills are modified.
  The LLM reads skills from the filesystem only — never from PostgreSQL.
  """

  use GenServer
  require Logger

  alias Kontor.AI.Skill
  alias Kontor.Repo

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def load_skill(name, namespace \\ "shared") do
    GenServer.call(__MODULE__, {:load_skill, name, namespace})
  end

  def sync_skill_to_fs(%Skill{} = skill) do
    GenServer.cast(__MODULE__, {:sync_skill, skill})
  end

  def regenerate_classifier(tenant_id) do
    GenServer.cast(__MODULE__, {:regenerate_classifier, tenant_id})
  end

  @impl true
  def init(_opts) do
    send(self(), :initial_sync)
    {:ok, %{synced: false}}
  end

  @impl true
  def handle_info(:initial_sync, state) do
    sync_all_skills()
    {:noreply, %{state | synced: true}}
  end

  @impl true
  def handle_call({:load_skill, name, namespace}, _from, state) do
    result = case File.read(skill_path(namespace, name)) do
      {:ok, content} -> {:ok, parse_skill(content)}
      {:error, _} -> {:error, :not_found}
    end
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:sync_skill, skill}, state) do
    write_skill_to_fs(skill)
    {:noreply, state}
  end

  def handle_cast({:regenerate_classifier, tenant_id}, state) do
    do_regenerate_classifier(tenant_id)
    {:noreply, state}
  end

  defp sync_all_skills do
    import Ecto.Query

    # Sync priv/skills/ default files first, then overlay DB skills
    sync_default_skills()

    skills = Repo.all(from s in Skill, where: s.active == true)
    Enum.each(skills, &write_skill_to_fs/1)
    Logger.info("SkillLoader: synced #{length(skills)} DB skills to filesystem")
  end

  defp sync_default_skills do
    # Default skills ship in priv/skills/ — they are already on disk, no action needed
    :ok
  end

  defp write_skill_to_fs(%Skill{} = skill) do
    path = skill_path(skill.namespace, skill.name)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, skill.content)
  end

  defp skill_path("shared", name) do
    base = Application.get_env(:kontor, :skills_path)[:shared] || "priv/skills/shared"
    Path.join(base, "#{name}.md")
  end

  defp skill_path(namespace, name) do
    Path.join(["priv/skills", namespace, "#{name}.md"])
  end

  defp parse_skill(content) do
    case String.split(content, "---\n", parts: 3) do
      [_, yaml_str, body] ->
        case YamlElixir.read_from_string(yaml_str) do
          {:ok, fm} -> %{frontmatter: fm, body: body, raw: content}
          _ -> %{frontmatter: %{}, body: content, raw: content}
        end
      _ ->
        %{frontmatter: %{}, body: content, raw: content}
    end
  end

  defp do_regenerate_classifier(tenant_id) do
    import Ecto.Query

    skills = Repo.all(
      from s in Skill,
      where: s.tenant_id == ^tenant_id and s.active == true and s.name != "classifier"
    )

    routing = skills
    |> Enum.map(fn s -> "- **#{s.name}** (namespace: #{s.namespace})" end)
    |> Enum.join("\n")

    case Repo.get_by(Skill, tenant_id: tenant_id, namespace: "shared", name: "classifier") do
      nil ->
        Logger.warning("SkillLoader: classifier not found, skipping regeneration")

      classifier ->
        content = build_classifier(routing)
        updated = Ecto.Changeset.change(classifier, content: content, version: classifier.version + 1)
        Repo.update!(updated)
        write_skill_to_fs(%{classifier | content: content})
    end
  end

  defp build_classifier(routing_table) do
    """
    ---
    name: classifier
    namespace: shared
    version: 1
    author: system
    locked: false
    trigger:
      tier: 1
    input_schema:
      - subject
      - sender
      - recipients
    output_schema:
      - category
      - urgency
      - tier2_skills
      - context_depth
    priority: 0
    ---

    # Email Classifier

    You are the Tier 1 email classifier for Kontor. Given only the email subject, sender,
    and recipients, determine which Tier 2 processing skills to invoke.

    ## Available Tier 2 Skills

    #{routing_table}

    ## Task

    Output JSON with:
    - category: "work" | "personal" | "newsletter" | "automated" | "support" | "sales" | "other"
    - urgency: float 0.0-1.0
    - tier2_skills: array of skill names to invoke
    - context_depth: object mapping skill_name -> "headers_only" | "first_200" | "full_body"

    ## Rules

    - Newsletters/digests: empty tier2_skills, context_depth irrelevant
    - Emails needing reply: include "reply_drafter", context_depth: full_body
    - Meeting requests: include "meeting_setup", context_depth: full_body
    - Deadline mentions: include "calendar_reminder", context_depth: full_body
    - Always include "scorer" and "thread_summarizer" for non-automated emails
    - Include "task_extractor" when action is likely required
    - Minimize token usage — avoid full_body when not needed
    """
  end
end
