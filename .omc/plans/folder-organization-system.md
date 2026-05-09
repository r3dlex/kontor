# Plan: Folder Organization System

**Date:** 2026-04-07
**Status:** Ready for execution

---

## RALPLAN-DR Summary

### Principles

1. **Immutability over reversibility** — folder model choice is a one-way door; encode the lock at schema + UI level, not runtime logic.
2. **Bootstrap before acting** — the system classifies and suggests from day one but does not move a single email until ≥50 have been processed; safe defaults win.
3. **Conservative folder mutation** — prefer mapping to existing folders over creating new ones; never split a folder unless the 80% distinctness threshold is met.
4. **Pipeline owns suggestions, worker owns moves** — the AI pipeline produces `folder_suggestion` records; the Oban cron worker is the sole entity that calls Himalaya to execute moves.
5. **Skill is the only thing that changes per model** — all model-specific branching lives in the `folder_organizer.md` prompt, not in Elixir business logic.

### Decision Drivers (top 3)

1. **Safety of existing mail** — a bug should never move hundreds of emails unexpectedly; end-of-day batch + bootstrap threshold are the primary safeguards.
2. **Minimal schema surface** — add exactly three columns to `mailboxes` and one new `folder_suggestions` table; avoid premature normalisation.
3. **Oban consistency** — all scheduled work already flows through Oban; the new worker must fit that pattern (queue, cron entry, max_attempts).

### Key Decisions — Options Considered

#### Decision 1: Where to persist folder suggestions

**Option A — New `folder_suggestions` table (chosen)**
- Pros: clean separation of concern; query-able by status (pending/applied/skipped); retryable; auditable.
- Cons: one more table; requires migration.

**Option B — `folder_suggestion` JSON column on `emails`**
- Pros: no new table; simpler migration.
- Cons: cannot efficiently query pending suggestions across mailboxes; no status tracking; harder to mark applied without touching email rows.

**Chosen:** Option A. The end-of-day worker must efficiently enumerate pending suggestions; a dedicated table with an index on `(mailbox_id, status, suggested_at)` is the only clean path.

#### Decision 2: Where folder model selection lives in the UI

**Option A — In SettingsView (existing mailbox config section, chosen)**
- Pros: model selector is mailbox-scoped config, same as polling_interval_seconds and task_age_cutoff_months which already live here; no new route/view needed.
- Cons: settings view is not explicitly "import wizard" UX.

**Option B — Dedicated MailboxSetupView (new file)**
- Pros: step-by-step wizard feel.
- Cons: no existing wizard flow; adds a new route; overkill for a single select field.

**Chosen:** Option A. Extend the existing mailbox row in SettingsView with the model selector. Lock the selector (`disabled` attribute) when `folder_model_locked` is true on the mailbox.

#### Decision 3: Bootstrap counter location

**Option A — `folder_bootstrap_count` on `mailboxes` table (chosen)**
- Pros: single source of truth per mailbox; easy threshold check in pipeline and worker.
- Cons: high-frequency increment during bulk import (atomic `update_counter` call is safe).

**Option B — Derive count from `emails` table at query time**
- Pros: no extra column.
- Cons: expensive COUNT query on every pipeline run; not practical at scale.

**Chosen:** Option A. Use `Repo.update_all` with `inc:` to atomically increment without a read-modify-write race.

---

## Context

The Kontor AI pipeline already has a `folder_organizer` Tier 2 skill and a `manage_folder` sandbox action. Neither is connected to any scheduling mechanism or model-awareness. The `mailboxes` schema has no folder-related fields. This plan adds the missing layer end-to-end: schema, skill rewrite, suggestion storage, Oban cron worker, importer counter, pipeline wiring, and frontend lock.

---

## Work Objectives

1. Add three fields to `mailboxes` and a new `folder_suggestions` table via Ecto migration.
2. Extend `Mailbox` schema + changeset with validation for `folder_model` enum.
3. Rewrite `folder_organizer.md` to be model-aware with bootstrap guard and conservative split rules.
4. Create `FolderOrganizerWorker` as an Oban worker running at 23:00 UTC daily.
5. Update `Importer` to atomically increment `folder_bootstrap_count` on each new email and set `folder_model_locked`.
6. Update `Pipeline.post_process/4` to persist the `folder_organizer` skill result as a `folder_suggestions` row.
7. Add the folder model selector to `SettingsView.vue` with lock enforcement.

---

## Guardrails

**Must Have**
- Migration timestamp `20260408000001` (next after existing `20260407*` migrations).
- `folder_model` values must be exactly `["structural_category", "action_based", "decision"]`; `structural_category` is the default.
- Bootstrap threshold is 50; below threshold the skill outputs `action: none` and the pipeline stores the suggestion with `status: "skipped_bootstrap"` (not "pending").
- The Oban worker must only call Himalaya `move_email` for suggestions with `status: "pending"` and `mailbox.folder_bootstrap_count >= 50`.
- All Himalaya calls go through `Kontor.MCP.HimalayaClient`; no direct protocol calls from Elixir.
- `folder_model_locked` flips to `true` on the first email import for a mailbox (not on model selection).
- The sandbox `manage_folder` action is already in `@allowed_actions`; no change needed there.
- New `folder_organizer_batch` queue added to Oban config (keeps folder moves isolated from mail_import throughput).

**Must NOT Have**
- Real-time folder moves triggered per email — suggestions are only applied by the nightly cron.
- `folder_model` changes after `folder_model_locked = true` — the changeset must reject this.
- New folder creation unless the model's canonical mapping explicitly requires it and no existing folder is a close match.
- Any email body read inside the `FolderOrganizerWorker` — it works from pre-computed suggestions only.

---

## Task Flow

```
Step 1: Migration + Schema
  └─ priv/repo/migrations/20260408000001_add_folder_model_to_mailboxes.exs
  └─ priv/repo/migrations/20260408000002_create_folder_suggestions.exs
  └─ lib/kontor/accounts/mailbox.ex  (fields + changeset)
  └─ lib/kontor/mail/folder_suggestion.ex  (new schema)

Step 2: Skill Rewrite
  └─ priv/skills/shared/folder_organizer.md  (model-aware, bootstrap guard)

Step 3: Oban Worker
  └─ lib/kontor/mail/folder_organizer_worker.ex  (new)
  └─ config/config.exs  (queue + cron entry)

Step 4: Importer Update
  └─ lib/kontor/mail/importer.ex  (increment counter, set locked)

Step 5: Pipeline Update
  └─ lib/kontor/ai/pipeline.ex  (pass model context, persist suggestion)

Step 6: Frontend
  └─ frontend/src/views/SettingsView.vue  (model selector + lock)
```

---

## Detailed TODOs

### Step 1 — Migration + Schema

**File:** `priv/repo/migrations/20260408000001_add_folder_model_to_mailboxes.exs`

```
alter table(:mailboxes) do
  add :folder_model, :string, default: "structural_category", null: false
  add :folder_bootstrap_count, :integer, default: 0, null: false
  add :folder_model_locked, :boolean, default: false, null: false
end
create index(:mailboxes, [:folder_model])
```

Acceptance criteria:
- `mix ecto.migrate` succeeds on a clean DB and on an existing DB with mailboxes rows.
- Default values apply to all existing rows automatically.

---

**File:** `priv/repo/migrations/20260408000002_create_folder_suggestions.exs`

```
create table(:folder_suggestions, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :tenant_id, :string, null: false
  add :mailbox_id, references(:mailboxes, type: :binary_id, on_delete: :delete_all), null: false
  add :email_id, references(:emails, type: :binary_id, on_delete: :delete_all), null: false
  add :folder_model, :string, null: false
  add :action, :string, null: false          # "move" | "none"
  add :target_folder, :string
  add :create_if_missing, :boolean, default: false
  add :confidence, :float
  add :reason, :string
  add :status, :string, default: "pending", null: false  # pending | applied | skipped_bootstrap | failed
  add :applied_at, :utc_datetime
  timestamps(type: :utc_datetime)
end
create index(:folder_suggestions, [:mailbox_id, :status, :inserted_at])
create index(:folder_suggestions, [:tenant_id])
create unique_index(:folder_suggestions, [:email_id])  # one suggestion per email
```

Acceptance criteria:
- `mix ecto.migrate` succeeds.
- Unique index on `email_id` prevents duplicate suggestions for the same email.
- `on_delete: :delete_all` ensures cleanup when a mailbox or email is removed.

---

**File:** `lib/kontor/mail/folder_suggestion.ex` (new)

Module: `Kontor.Mail.FolderSuggestion`

```
schema "folder_suggestions" do
  field :tenant_id, :string
  field :folder_model, :string
  field :action, :string
  field :target_folder, :string
  field :create_if_missing, :boolean, default: false
  field :confidence, :float
  field :reason, :string
  field :status, :string, default: "pending"
  field :applied_at, :utc_datetime
  belongs_to :mailbox, Kontor.Accounts.Mailbox
  belongs_to :email, Kontor.Mail.Email
  timestamps(type: :utc_datetime)
end

def changeset(suggestion, attrs) do
  suggestion
  |> cast(attrs, [...all fields...])
  |> validate_required([:tenant_id, :mailbox_id, :email_id, :folder_model, :action, :status])
  |> validate_inclusion(:action, ["move", "none"])
  |> validate_inclusion(:status, ["pending", "applied", "skipped_bootstrap", "failed"])
  |> unique_constraint(:email_id)
end
```

Acceptance criteria:
- `FolderSuggestion.changeset/2` rejects invalid `action` and `status` values.
- `unique_constraint(:email_id)` raises a changeset error on duplicate email suggestions.

---

**File:** `lib/kontor/accounts/mailbox.ex`

Changes:
- Add three fields to schema: `folder_model :string`, `folder_bootstrap_count :integer`, `folder_model_locked :boolean`.
- Add `has_many :folder_suggestions, Kontor.Mail.FolderSuggestion`.
- Update `changeset/2`:
  - Cast the three new fields.
  - `validate_inclusion(:folder_model, ["structural_category", "action_based", "decision"])`.
  - Add a custom validation: if `folder_model_locked` is already `true` on the existing record (checked via `get_field`), and `folder_model` is being changed, add an error `"cannot change folder model after mailbox has processed emails"`.

```elixir
def changeset(mailbox, attrs) do
  mailbox
  |> cast(attrs, [...existing..., :folder_model, :folder_bootstrap_count, :folder_model_locked])
  |> validate_required(...)
  |> validate_inclusion(:folder_model, ["structural_category", "action_based", "decision"])
  |> validate_folder_model_immutable()
  |> ...
end

defp validate_folder_model_immutable(changeset) do
  if get_field(changeset, :folder_model_locked) && get_change(changeset, :folder_model) do
    add_error(changeset, :folder_model, "cannot change folder model after mailbox has processed emails")
  else
    changeset
  end
end
```

Acceptance criteria:
- Changeset accepts `folder_model` changes when `folder_model_locked` is false.
- Changeset rejects `folder_model` changes when `folder_model_locked` is true.
- `folder_model` values outside the three allowed values are rejected.

---

### Step 2 — Skill Rewrite

**File:** `priv/skills/shared/folder_organizer.md`

Update YAML frontmatter:
- `version: 2`
- `input_schema`: replace `available_folders` with `folder_model`, `folder_bootstrap_count`, `available_folders`, `source_email`.
- `output_schema`: `folder_action` (unchanged key, richer structure).

Full rewritten body must include:

**Section 1 — Bootstrap guard**
```
## Bootstrap check

If `folder_bootstrap_count < 50`, output:
{"folder_action": {"action": "none", "reason": "bootstrap_threshold_not_reached", "confidence": 1.0}}
Stop. Do not evaluate the email further.
```

**Section 2 — Model-aware routing rules**

```
## Model A — Structural / Category (folder_model = "structural_category")

Sub-model variants recognised from available_folders:
- PARA: target folders are Projects, Areas, Resources, Archive
- Category-Based: Finance, Personal, Clients, Travel, etc.
- Search-First: single Archive folder

Mapping rules:
1. Check available_folders for PARA names. If present, use PARA routing.
2. Check for Category-Based names. If present, route to closest category.
3. Fallback: move to Archive (create if missing).

## Model B — Action-Based (folder_model = "action_based")

Sub-model variants:
- 4-Folder: Inbox / Action-Follow-up / Waiting-For / Archive-File
- Time-Based: Today / This-Week / This-Month-Quarter / FYI-Reference

Rules:
- Emails requiring action from sender → Action-Follow-up (or Today if urgent)
- Emails awaiting external response → Waiting-For
- FYI / newsletters / low-priority → FYI-Reference or Archive-File

## Model C — Decision / 4 D's (folder_model = "decision")

Do: confidence > 0.8 AND estimated_action_time < 2 minutes → flag for immediate action
Delete: spam, unsubscribe, automated with no value → Spam/Junk
Delegate: clearly addressed to a third party who should act → Delegate folder
Defer: requires action but not immediate → Action (or equivalent in available_folders)
```

**Section 3 — Conservative folder evolution rules**
```
## Existing folder mapping

Before creating any new folder:
1. Find the closest match in available_folders (case-insensitive, partial match allowed).
2. If match confidence > 0.7, use the existing folder.
3. Only set create_if_missing: true if no close match exists AND the model's canonical mapping requires a distinct folder.

## Split guard

Do NOT split an existing folder unless:
- > 80% of the emails being routed clearly belong to one of exactly two distinct groups.
- Output action: "none" and add reason: "split_guard_active" in that case.
```

**Section 4 — Output format**
```json
{
  "folder_action": {
    "action": "move" | "none",
    "target_folder": "Archive",
    "create_if_missing": false,
    "confidence": 0.87,
    "reason": "PARA model — reference material with no action required"
  }
}
```

Acceptance criteria:
- Skill frontmatter parses without error via `SkillLoader.load_skill/2`.
- When `folder_bootstrap_count < 50`, output is always `action: "none"` with reason `bootstrap_threshold_not_reached`.
- Each model branch produces a plausible target folder when tested manually against sample emails.
- Conservative mapping prefers existing folder names from `available_folders`.

---

### Step 3 — Oban Worker

**File:** `lib/kontor/mail/folder_organizer_worker.ex` (new)

Module: `Kontor.Mail.FolderOrganizerWorker`

```elixir
use Oban.Worker,
  queue: :folder_organizer_batch,
  max_attempts: 3
```

`perform/1` implementation:

1. Query all tenant_ids via `Kontor.Accounts.list_tenant_ids/0`.
2. For each tenant, query mailboxes where `active = true AND folder_bootstrap_count >= 50`.
3. For each eligible mailbox, query `folder_suggestions` where `status = "pending"` and `inserted_at <= now() - 1 hour` (avoid suggestions added late in the same day).
4. For each pending suggestion with `action = "move"`:
   a. Call `Kontor.MCP.HimalayaClient.move_email(mailbox.himalaya_config, email.message_id, suggestion.target_folder)`.
   b. On `:ok` → update suggestion `status = "applied"`, `applied_at = utc_now()`.
   c. On `{:error, reason}` → update suggestion `status = "failed"`, log warning.
5. For suggestions with `action = "none"` and `status = "pending"` → update `status = "applied"` (nothing to move, mark complete).
6. Log summary: `"FolderOrganizerWorker: applied N moves, F failed, S skipped for tenant T"`.

Function signatures:
- `perform(%Oban.Job{}) :: :ok`
- `process_mailbox(mailbox, tenant_id) :: {integer(), integer()}` (applied, failed counts)
- `apply_suggestion(suggestion, mailbox) :: :ok | {:error, term()}`

Acceptance criteria:
- Worker only calls `HimalayaClient.move_email/3` for suggestions with `status = "pending"` on mailboxes with `folder_bootstrap_count >= 50`.
- Suggestions with `action = "none"` are marked `"applied"` without any Himalaya call.
- Failed Himalaya calls leave suggestion as `"failed"`, do not crash the worker (rescued with Logger.warning).
- `max_attempts: 3` means the whole batch retries on worker crash, not individual suggestions (individual failures are handled inside the loop).

---

**File:** `config/config.exs`

Two changes:

1. Add `folder_organizer_batch: 2` to `queues:` list.
2. Add cron entry:
```elixir
{"0 23 * * *", Kontor.Mail.FolderOrganizerWorker}
```
inside the `Oban.Plugins.Cron` crontab list (alongside existing `MarkdownBackfillWorker` entry).

Acceptance criteria:
- `mix compile` succeeds.
- `Oban.Plugins.Cron` config parses; no atom errors.

---

### Step 4 — Importer Update

**File:** `lib/kontor/mail/importer.ex`

Change `import_email/3` (specifically the `{:ok, %Email{id: _id} = email}` branch in the `case Repo.insert` block):

After `upsert_thread(email, tenant_id)`, add two calls:

```elixir
# Atomically increment bootstrap counter
Repo.update_all(
  from(m in Kontor.Accounts.Mailbox, where: m.id == ^mailbox.id),
  inc: [folder_bootstrap_count: 1]
)

# Lock folder model after first email import
unless mailbox.folder_model_locked do
  Repo.update_all(
    from(m in Kontor.Accounts.Mailbox, where: m.id == ^mailbox.id and m.folder_model_locked == false),
    set: [folder_model_locked: true]
  )
end
```

Note: the `mailbox` struct is already fetched at the top of `run_import/3`. The `unless` guard uses the cached value — a minor TOCTOU is acceptable here since the lock is monotonic (false → true only).

Pass `mailbox` down through `import_folder/6` and `import_email/3` (currently `import_email` receives `mailbox` already — verify the existing signature handles this).

Acceptance criteria:
- `folder_bootstrap_count` increments by 1 for every new (non-duplicate) email imported.
- `folder_model_locked` transitions from `false` to `true` on the first new email import for a mailbox.
- Duplicate emails (the `{:ok, %Email{id: nil}}` branch) do NOT increment the counter.
- No race condition: `Repo.update_all` with `inc:` is atomic at the DB level.

---

### Step 5 — Pipeline Update

**File:** `lib/kontor/ai/pipeline.ex`

**Change 1 — `run_tier2/4`**

Preload mailbox fields for folder model context. The `email` struct has `mailbox_id`; load or accept the mailbox as an additional param. Simplest approach: after existing opts extraction at the top of `run_tier2`, fetch:

```elixir
mailbox = Repo.get(Kontor.Accounts.Mailbox, email.mailbox_id)
folder_model = (mailbox && mailbox.folder_model) || "structural_category"
folder_bootstrap_count = (mailbox && mailbox.folder_bootstrap_count) || 0
```

Pass `{folder_model, folder_bootstrap_count}` as additional opts into `run_one_tier2/5` only when the skill name is `"folder_organizer"`:

```elixir
{name, Task.async(fn ->
  extra = if name == "folder_organizer",
    do: %{folder_model: folder_model, folder_bootstrap_count: folder_bootstrap_count},
    else: %{}
  run_one_tier2(name, email, context_depth, tenant_id, extra)
end)}
```

**Change 2 — `run_one_tier2/5`**

Add `extra` parameter. When building input via `build_email_input/2`, merge `extra` into the input map:

```elixir
input = build_email_input(email, context_depth) |> Map.merge(extra)
```

Also pass `available_folders` by fetching from Himalaya:

```elixir
available_folders =
  if name == "folder_organizer" do
    mailbox_config = Repo.get(Kontor.Accounts.Mailbox, email.mailbox_id) |> Map.get(:himalaya_config)
    case Kontor.MCP.HimalayaClient.list_folders(mailbox_config) do
      {:ok, folders} -> folders
      _ -> []
    end
  else
    []
  end
input = Map.put(input, :available_folders, available_folders)
```

**Change 3 — `post_process/4`**

Add a `folder_organizer` result handler after the existing skill handlers:

```elixir
if folder_result = Map.get(tier2, "folder_organizer") do
  if folder_action = Map.get(folder_result, "folder_action") do
    action_str = Map.get(folder_action, "action", "none")
    mailbox_id = email.mailbox_id
    mailbox = Repo.get(Kontor.Accounts.Mailbox, mailbox_id)
    bootstrap_count = (mailbox && mailbox.folder_bootstrap_count) || 0
    status = if bootstrap_count < 50, do: "skipped_bootstrap", else: "pending"

    attrs = %{
      tenant_id: tenant_id,
      mailbox_id: mailbox_id,
      email_id: email.id,
      folder_model: (mailbox && mailbox.folder_model) || "structural_category",
      action: action_str,
      target_folder: Map.get(folder_action, "target_folder"),
      create_if_missing: Map.get(folder_action, "create_if_missing", false),
      confidence: Map.get(folder_action, "confidence"),
      reason: Map.get(folder_action, "reason"),
      status: status
    }

    Repo.insert(
      Kontor.Mail.FolderSuggestion.changeset(%Kontor.Mail.FolderSuggestion{}, attrs),
      on_conflict: :nothing,
      conflict_target: [:email_id]
    )
  end
end
```

Acceptance criteria:
- When `folder_organizer` is in the Tier 2 skill list for an email, a `folder_suggestions` row is inserted.
- Emails below bootstrap threshold get `status = "skipped_bootstrap"`.
- Emails at/above threshold get `status = "pending"`.
- Duplicate pipeline runs for the same email are a no-op (`on_conflict: :nothing`).
- `available_folders` is included in the skill prompt input only for `folder_organizer`.

---

### Step 6 — Frontend

**File:** `frontend/src/views/SettingsView.vue`

**Template change** — inside the `v-for="mb in mailboxes"` `.mailbox-config` div, add a new `<label>` after the existing task cutoff label:

```html
<label>
  Folder model
  <select
    v-model="mb.folder_model"
    :disabled="mb.folder_model_locked"
    @change="saveMailbox(mb)"
    :title="mb.folder_model_locked ? 'Cannot change after emails have been processed' : ''"
  >
    <option value="structural_category">Structural / Category</option>
    <option value="action_based">Action-Based</option>
    <option value="decision">Decision (4 D\'s)</option>
  </select>
  <span v-if="mb.folder_model_locked" class="hint locked-hint">Locked after first import</span>
</label>
```

**Script change** — extend `saveMailbox(mb)` to include the new field:

```js
async function saveMailbox(mb) {
  await api.patch(`/mailboxes/${mb.id}`, {
    mailbox: {
      polling_interval_seconds: mb.polling_interval_seconds,
      task_age_cutoff_months: mb.task_age_cutoff_months,
      folder_model: mb.folder_model
    }
  })
}
```

**Style change** — add `.locked-hint` class:

```css
.locked-hint { font-size: 11px; color: #f87171; }
```

Acceptance criteria:
- Selector renders for each mailbox with three options.
- Selector is `disabled` when `folder_model_locked` is `true`.
- `saveMailbox` sends `folder_model` to the backend; the backend changeset rejects the value if locked (returns 422 — no additional frontend error handling required for v1).
- The locked hint is visible when the selector is disabled.

---

## Success Criteria

The implementation is complete when all of the following are true:

1. `mix ecto.migrate` runs both new migrations cleanly.
2. `Kontor.Accounts.Mailbox` changeset rejects: (a) invalid `folder_model` values, (b) `folder_model` changes when `folder_model_locked` is true.
3. `SkillLoader.load_skill("folder_organizer", "shared")` loads without error; frontmatter includes `folder_model` in `input_schema`.
4. A sample pipeline run for an email on a mailbox with `folder_bootstrap_count = 0` produces a `folder_suggestions` row with `status = "skipped_bootstrap"`.
5. A sample pipeline run for an email on a mailbox with `folder_bootstrap_count = 55` produces a `folder_suggestions` row with `status = "pending"`.
6. `FolderOrganizerWorker.perform/1` called manually with pending suggestions calls `HimalayaClient.move_email/3` for `action = "move"` suggestions and marks them `"applied"`.
7. The SettingsView renders a folder model selector that is disabled when `folder_model_locked = true`.
8. Existing tests (`mix test`) pass without modification.

---

## ADR — Architecture Decision Record

**Decision:** Persist folder suggestions in a dedicated `folder_suggestions` table; execute moves in a nightly Oban worker; lock `folder_model` at schema level.

**Drivers:**
- Safety: no real-time moves; batch gives a daily review window.
- Auditability: suggestion status (`pending/applied/failed/skipped_bootstrap`) is queryable.
- Consistency with existing Oban patterns (`MarkdownBackfillWorker`, `ScheduledSender`).

**Alternatives considered:**
- Storing suggestions as a JSON column on `emails` — rejected: no efficient status query.
- Real-time moves on each pipeline run — rejected: too risky; no review window.
- New `MailboxSetupView` wizard — rejected: overkill; `SettingsView` already handles all mailbox config.
- Deriving bootstrap count from `emails` table at query time — rejected: expensive COUNT; atomic increment on `mailboxes` is O(1).

**Why chosen:** The dedicated table + nightly worker pattern maps directly onto the existing Oban infrastructure, keeps the pipeline's responsibility limited to suggestion production, and provides a clean audit trail.

**Consequences:**
- One new table (`folder_suggestions`) and two new columns on `mailboxes` — low schema footprint.
- Himalaya is called only from `FolderOrganizerWorker`, preserving the invariant that email protocol calls are isolated.
- The 23:00 UTC cron means moves happen once per day; users who add a mailbox late in the day will see their first folder organisation the next morning.

**Follow-ups (v2):**
- Add a "review pending suggestions" UI before the nightly run executes.
- Allow per-thread manual override of a folder suggestion.
- Expose `folder_bootstrap_count` progress in the import progress broadcast.

---

## Open Questions

See `/Users/andreburgstahler/Ws/Personal/kontor/.omc/plans/open-questions.md` for tracked items.
