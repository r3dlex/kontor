# Folder Organization System Upgrade

**Created:** 2026-04-08
**Revised:** 2026-04-08 (Architect + Critic feedback incorporated)
**Status:** APPROVED — Planner + Architect + Critic consensus (4 iterations)
**Complexity:** HIGH (new schemas, skill additions, pipeline changes, adaptive learning)

---

## RALPLAN-DR Summary

### Principles (5)

1. **Headers-only Tier 1 invariant** — The Tier 1 classifier remains headers-only (`context_depth: "none"` for ~50% of emails). Enrichments to Tier 1 output (`priority_score`, `has_actionable_task`) must be derivable from headers alone. Full-body analysis stays in Tier 2.
2. **Additive schema evolution** — New tables and columns only; no destructive migrations on existing data. Existing `folder_suggestions` and `mailbox` schemas get new fields but retain backward compatibility.
3. **Skill-as-prompt separation** — All LLM behavior changes live in `.md` skill files, not in Elixir code. The pipeline orchestrates; skills decide.
4. **Progressive trust** — Guards (bootstrap count, confidence thresholds, volume thresholds, folder caps) prevent the system from acting before it has enough signal.
5. **Sandbox-first writes** — Every new action type (apply labels, record correction, update sender rules) must be registered in `Sandbox.@allowed_actions` with explicit `do_execute/3` function heads before use.

### Decision Drivers (top 3)

1. **Token efficiency** — The current pipeline routes ~50% of emails with `context_depth: "none"` (newsletters, spam, automated notifications), skipping full-body cost. A unified classifier forcing full-body on every email would increase total token spend. The two-phase approach preserves this optimization.
2. **Data model for labels and corrections** — No tables exist for email labels, sender rules, or user corrections. These must be created before any adaptive learning can work.
3. **Incremental enrichment over big-bang rewrite** — Enriching the existing Tier 1 classifier with two new header-derivable fields and adding a lightweight Tier 2 labeler skill is lower-risk than replacing the entire classification architecture.

### Viable Options

#### Option A: Two-Phase Enrichment (selected)

**Phase 1 (this plan):** Enrich the existing Tier 1 classifier to also output `priority_score` (0-100) and `has_actionable_task` (true/false) from headers-only signals. Add a new lightweight Tier 2 `labeler` skill for multi-dimensional labels. Rewrite `folder_organizer.md` for action-based folders. Keep Tier 1 as headers-only, keep Tier 2 parallel execution. Add all 4 new DB tables and context functions.

**Phase 2 (future, out of scope):** After production `context_depth` distribution data exists, make a data-driven decision on whether full unification reduces cost.

**Pros:**
- Preserves headers-only Tier 1 invariant (no token cost increase for ~50% of emails)
- Each skill remains independently testable and rollback-able
- Incremental rollout: classifier enrichment, labeler, folder_organizer can ship independently
- Existing Tier 2 parallel execution model is preserved

**Cons:**
- Priority score from headers-only may be less accurate than full-body analysis
- Two skills (labeler + folder_organizer) instead of one unified output
- Phase 2 decision deferred — full unification benefits delayed

#### Option B: Unified Classifier (invalidated)

Replace Tier 1 classifier + Tier 2 folder_organizer + Tier 2 scorer with a single unified classifier producing the full JSON spec in one call.

**Why invalidated:** Violates the codebase's headers-only Tier 1 invariant. The current pipeline routes ~50% of emails with `context_depth: "none"` — these never incur full-body token cost. The unified approach forces full-body on every email, potentially *increasing* total token spend rather than reducing it. Cannot be validated without production `context_depth` distribution data (deferred to Phase 2).

### ADR

**Decision:** Two-Phase Enrichment (Option A)
**Drivers:** Token efficiency, Tier 1 headers-only invariant, incremental risk reduction
**Alternatives considered:** Unified Classifier (Option B) — invalidated due to Tier 1 invariant violation
**Why chosen:** Preserves the ~50% headers-only routing that avoids full-body token cost; allows data-driven Phase 2 decision
**Consequences:** Priority scoring limited to header signals in Tier 1; labeling requires a separate Tier 2 skill call; two prompts to maintain instead of one
**Follow-ups:** After 30 days of production data, analyze `context_depth` distribution to evaluate Phase 2 unification

---

## Implementation Plan

### Step 1: Database Migration — New Tables and Columns

**Files:**
- CREATE `priv/repo/migrations/YYYYMMDD000001_upgrade_folder_organization.exs`

**Changes:**

```
1. Create `email_labels` table:
   - id (binary_id PK)
   - tenant_id (string, not null)
   - email_id (references emails, not null, unique)
   - labels (array of strings) — e.g. ["Receipt", "VIP", "Automated"]
   - priority_score (integer, 0-100)
   - has_actionable_task (boolean, default false)
   - task_summary (string, nullable)
   - task_deadline (utc_datetime, nullable)
   - ai_confidence (float)
   - ai_reasoning (string)
   - inserted_at (utc_datetime)
   Index: [:tenant_id], [:email_id]

2. Create `sender_rules` table:
   - id (binary_id PK)
   - tenant_id (string, not null)
   - mailbox_id (references mailboxes, not null)
   - sender_pattern (string, not null) — email address or domain
   - rule_type (string) — "folder_override" | "auto_archive" | "label_override"
   - rule_data (map) — e.g. %{"folder" => "Archive", "labels" => ["Notification"]}
   - confidence (string) — "tentative" | "confident"
   - correction_count (integer, default 0)
   - source (string) — "user_correction" | "system_detected"
   - active (boolean, default true)
   - inserted_at, updated_at (utc_datetime)
   Index: [:tenant_id, :mailbox_id, :sender_pattern], unique
   Index: [:mailbox_id, :rule_type]

3. Create `folder_corrections` table:
   - id (binary_id PK)
   - tenant_id (string, not null)
   - mailbox_id (references mailboxes, not null)
   - email_id (references emails, not null)
   - from_folder (string)
   - to_folder (string)
   - sender (string)
   - sender_domain (string)
   - recorded_at (utc_datetime)
   Index: [:tenant_id, :mailbox_id, :sender]
   Index: [:mailbox_id, :sender_domain]

4. Create `newsletter_engagement` table:
   - id (binary_id PK)
   - tenant_id (string, not null)
   - mailbox_id (references mailboxes, not null)
   - sender_domain (string, not null)
   - consecutive_unread (integer, default 0)
   - last_received_at (utc_datetime)
   - auto_archive (boolean, default false)
   - inserted_at, updated_at (utc_datetime)
   Index: [:mailbox_id, :sender_domain], unique

5. Alter `folder_suggestions` table:
   - Add: labels (array of strings, default [])
   - Add: priority_score (integer, nullable)
   - Add: reasoning (string, nullable)

6. Alter `mailboxes` table:
   - Add: folder_creation_guard (map, default %{"volume_threshold" => 5, "confidence_min" => 0.80, "max_active_folders" => 12})
   - Update: folder_model validation to include new default "action_based"
```

**Acceptance criteria:**
- Migration runs cleanly on a fresh database
- Migration runs cleanly on existing database with data in `folder_suggestions` and `mailboxes`
- All new indexes are created
- Rollback (`mix ecto.rollback`) works without error

---

### Step 2: Ecto Schemas for New Tables

**Files:**
- CREATE `lib/kontor/mail/email_label.ex`
- CREATE `lib/kontor/mail/sender_rule.ex`
- CREATE `lib/kontor/mail/folder_correction.ex`
- CREATE `lib/kontor/mail/newsletter_engagement.ex`
- MODIFY `lib/kontor/mail/folder_suggestion.ex` — add `:labels`, `:priority_score`, `:reasoning` fields and cast them
- MODIFY `lib/kontor/accounts/mailbox.ex` — add `:folder_creation_guard` field, update changeset

**Acceptance criteria:**
- Each schema has a `changeset/2` with proper validations
- `SenderRule` validates `rule_type` inclusion in `["folder_override", "auto_archive", "label_override"]`
- `SenderRule` validates `confidence` inclusion in `["tentative", "confident"]`
- `EmailLabel` validates `priority_score` range 0..100
- `FolderSuggestion` changeset still passes all existing tests after modification
- `Mailbox` changeset still passes all existing tests after modification

---

### Step 3: Context Module Functions

**Files:**
- MODIFY `lib/kontor/mail/mail.ex` — add functions for:
  - `record_folder_correction/4` — inserts a `FolderCorrection`, then calls `maybe_promote_sender_rule/3`. **Note:** called directly from `FolderCorrectionController` (Step 9), not through Sandbox and not from a worker.
  - `maybe_promote_sender_rule/3` — counts corrections for sender; if >= 3, upserts `SenderRule` with confidence "confident"
  - `get_sender_rules/2` — fetches active rules for a mailbox
  - `upsert_email_labels/2` — inserts/updates `EmailLabel` for an email. Signature: `upsert_email_labels(attrs :: map(), tenant_id :: String.t()) :: {:ok, EmailLabel.t()} | {:error, Ecto.Changeset.t()}`. `attrs` does NOT include tenant_id (passed separately).
  - `upsert_sender_rule/2` — upserts a `SenderRule` by `[tenant_id, mailbox_id, sender_pattern]` unique index. Returns `{:ok, %SenderRule{}} | {:error, changeset}`.
  - `create_folder_suggestion/2` — inserts a `FolderSuggestion` record from a folder_organizer result map. Signature: `create_folder_suggestion(attrs :: map(), tenant_id :: String.t()) :: {:ok, FolderSuggestion.t()} | {:error, Ecto.Changeset.t()}`. Called from `post_process/4` in the pipeline.
  - `get_email_labels/2` — fetches `EmailLabel` for an email by email_id and tenant_id
  - `update_newsletter_engagement/3` — increments `consecutive_unread` or resets on read; sets `auto_archive` when >= 2
  - `active_folder_count/2` — counts distinct folders in recent suggestions (for cap guard)
  - `weekly_folder_volume/3` — counts emails per folder in last 7 days (for volume threshold guard)

**Acceptance criteria:**
- `record_folder_correction` creates a correction record and returns `{:ok, correction}`
- After 3 corrections from the same sender to the same folder, `get_sender_rules` returns a "confident" rule for that sender
- `update_newsletter_engagement` sets `auto_archive: true` after 2 consecutive unreads
- `active_folder_count` returns an integer count of distinct active folders
- `get_email_labels` returns the `EmailLabel` struct or nil
- `upsert_sender_rule` upserts by unique [tenant_id, mailbox_id, sender_pattern] and returns `{:ok, %SenderRule{}}`
- `create_folder_suggestion` inserts a `FolderSuggestion` and returns `{:ok, %FolderSuggestion{}}`

---

### Step 4: Enrich Classifier Skill (Tier 1, headers-only)

**Files:**
- MODIFY `priv/skills/shared/classifier.md` — add `priority_score` and `has_actionable_task` to output schema

**New output schema (additions in bold context):**
```json
{
  "tier2_skills": ["thread_summarizer", "labeler", "task_extractor"],
  "urgency_estimate": 0.7,
  "category": "personal",
  "context_depth": "full_body",
  "priority_score": 72,
  "has_actionable_task": true
}
```

**Key constraints:**
- Input remains **headers-only**: subject, sender, recipients. No body content.
- `priority_score` (0-100) derived from header signals: sender importance, subject keywords (urgent, action required, deadline, etc.), recipient patterns (direct vs CC)
- `has_actionable_task` (boolean) derived from header signals: subject contains action verbs, deadline references, question patterns
- These are **pre-signals** — the Tier 2 `task_extractor` still does the full analysis with body content
- Existing fields (`tier2_skills`, `urgency_estimate`, `category`, `context_depth`) remain unchanged
- `tier2_skills` output options now include `"labeler"` as a valid Tier 2 skill name
- Bootstrap guard logic is preserved

**Acceptance criteria:**
- Classifier still receives only headers (subject, sender, recipients) as input
- Output JSON includes `priority_score` (integer 0-100) and `has_actionable_task` (boolean)
- All existing output fields are preserved and unchanged
- `"labeler"` appears in `tier2_skills` for emails that need label assignment
- Emails with `context_depth: "none"` still skip body fetching downstream

---

### Step 5: New `labeler` Tier 2 Skill

**Files:**
- CREATE `priv/skills/shared/labeler.md` — new Tier 2 skill for multi-dimensional label assignment

**Skill specification:**
- **Input:** email subject, sender, body (per `context_depth` from Tier 1), sender_rules, newsletter_engagement status
- **Output schema:**
  ```json
  {
    "labels": ["Receipt", "VIP"],
    "confidence": 0.88,
    "reasoning": "Payment confirmation from known vendor"
  }
  ```
- **Label taxonomy:**
  - Content-type: Receipt, Newsletter, Notification, Calendar, Travel, Social
  - Source: VIP, Automated, Internal, External
  - Priority: High, Medium, Low
- **Frontmatter:** `active: true`, `tier: 2`, output_schema with labels array, confidence float, reasoning string
- Newsletter sender identification: determined by labels containing "Newsletter" (not the deprecated `category` field from Tier 1)

**Acceptance criteria:**
- Skill file exists at `priv/skills/shared/labeler.md` with valid YAML frontmatter
- Frontmatter includes `active: true` and output_schema
- Label taxonomy covers all specified categories
- Output always includes `labels` (array), `confidence` (float), `reasoning` (string)

---

### Step 6: Rewrite `folder_organizer.md` for Action-Based Folders

**Files:**
- MODIFY `priv/skills/shared/folder_organizer.md` — rewrite prompt for action-based folder model

**Key changes:**
- Folder choices follow action-based model: **Inbox, Action Required, Waiting For, Read Later, Reference, Archive**
- Input includes: email content (per context_depth), priority_score (from Tier 1), sender_rules, available_folders, folder_model, folder_bootstrap_count
- **Labels are NOT available as input** — labeler runs in parallel and its results are only available after all Tier 2 tasks complete. Labels are denormalized into the FolderSuggestion record post-hoc in `post_process/4`. The folder_organizer makes its routing decision without label context (a known limitation of the parallel execution model; Phase 2 evaluation criterion: merge labeler+folder_organizer if label-aware routing improves accuracy).
- Sender-domain auto-archive rules in prompt: github.com notifications, slack.com, etc. -> Archive unless direct mention keywords detected
- Bootstrap guard remains: if `folder_bootstrap_count < 50`, output folder "Inbox" with `bootstrap_blocked` flag
- `folder_model_locked_at` immutability guard preserved
- Progressive folder creation guards preserved (checked in pipeline, not in skill prompt)

**Output schema:**
```json
{
  "folder": "Action Required",
  "confidence": 0.91,
  "reasoning": "Direct request with explicit deadline from VIP contact",
  "create_if_missing": false
}
```

**Acceptance criteria:**
- Folder organizer prompt references action-based folder set
- Bootstrap guard blocks folder assignment when count < 50
- Output includes `folder`, `confidence`, `reasoning`, `create_if_missing`
- Old `structural_category` folder model is still supported as fallback default

---

### Step 7: Pipeline Refactor

**Files:**
- MODIFY `lib/kontor/ai/pipeline.ex`

**Changes:**

1. **`run_classifier/2` (lines 59-75)** — Output now includes `priority_score` and `has_actionable_task`. No input changes needed (still headers-only). Update the fallback passthrough map to include `"priority_score" => 50, "has_actionable_task" => false`.

2. **`post_process/4` (lines 133-193)** — Add handling for new data:

   a) **Tier 1 `has_actionable_task` pre-signal:** If `tier1["has_actionable_task"] == true`, this serves as a pre-signal for the `task_extractor` Tier 2 skill. No direct action in `post_process` — the task_extractor still creates tasks as it does today. The pre-signal is informational and can be logged.

   b) **Labeler Tier 2 result handling:** If `tier2["labeler"]` exists, call `Sandbox.execute(:apply_labels, %{email_id: email.id, labels: labeler_result["labels"], confidence: labeler_result["confidence"], reasoning: labeler_result["reasoning"]}, tenant_id)`. Also write labels into the folder suggestion record (denormalized cache — see dual label storage note below).

   c) **Folder organizer Tier 2 result handling (NEW — this path did not exist before):** If `tier2["folder_organizer"]` exists, create a `FolderSuggestion` record using `Mail.create_folder_suggestion/2`. Field mapping from the new flat output schema to `FolderSuggestion` fields:
      - `result["folder"]` → `suggested_folder`
      - `result["confidence"]` → `confidence`
      - `result["reasoning"]` → `reasoning`
      - `result["create_if_missing"]` → `create_if_missing` (subject to progressive guards below)
      - `tier1["priority_score"]` → `priority_score` (Tier 1 pre-signal, stored for worker context)
      - `tier2["labeler"]["labels"]` (if available) → `labels` (denormalized cache; labels not available to folder_organizer at decision time since both run in parallel — this is post-hoc enrichment only)
      - `email.id` → `email_id`, `email.mailbox_id` → `mailbox_id`, `email.tenant_id` → `tenant_id`
      - `email.message_id` → `email_message_id` (required by FolderSuggestion changeset validation)
      - `status: "pending"` (default for FolderOrganizerWorker to pick up)
   - Note: `_tier1` in the current `post_process/4` signature must be changed to `tier1` so `tier1["priority_score"]` can be read.
   - **Compatibility shim for output schema:** `post_process/4` must handle both the new flat format (from the rewritten skill) and any legacy nested `folder_action` format (e.g., from mailbox-specific skill overrides still using the old schema): `suggested_folder = result["folder"] || get_in(result, ["folder_action", "target_folder"])`. Apply the same dual-key pattern for `confidence`, `reasoning`, and `create_if_missing`.

   d) **Scorer Tier 2 result handling is UNCHANGED.** The `scorer` skill continues to run as a Tier 2 skill and its 4-dimensional scores (`score_urgency`, `score_action`, `score_authority`, `score_momentum`) continue to be persisted via the existing `update_score` sandbox action. Tier 1 `priority_score` does NOT replace scorer — it is written only to `email_labels.priority_score` and `folder_suggestions.priority_score` as a folder-routing pre-signal, completely separate from thread scores.

3. **`run_tier2/4` (lines 77-98)** — Add `labeler` to the skill routing. It runs in parallel with other Tier 2 skills (no sequential change needed). The `build_folder_extra_context` function is extended to also provide context for the labeler skill (sender_rules, newsletter_engagement).

4. **Progressive folder creation guards in pipeline context:** Before setting `create_if_missing: true` on a folder suggestion, check `active_folder_count` against mailbox cap and `weekly_folder_volume` against threshold.

**Dual label storage (M2 clarification):**
- `email_labels` table = source of truth for persisted labels (queryable, indexed). Upserted when `:apply_labels` sandbox action executes.
- `folder_suggestions.labels` = denormalized cache for suggestion lifecycle only (so the suggestion record contains full context for `FolderOrganizerWorker`). Written when folder suggestion is created/updated.
- The frontend reads labels from `email_labels`, never from `folder_suggestions.labels`.

**Acceptance criteria:**
- Tier 1 `priority_score` is stored in `email_labels.priority_score` and `folder_suggestions.priority_score` only — it does NOT flow into `update_score` / thread scores
- Scorer Tier 2 skill continues to run and its 4-dimensional scores are persisted via `update_score` (no change)
- Labeler Tier 2 result triggers `:apply_labels` sandbox action
- Folder organizer Tier 2 result creates a `FolderSuggestion` record with `status: "pending"` via `Mail.create_folder_suggestion/2`
- `FolderSuggestion` fields are mapped from the new flat folder_organizer output schema as specified
- Labels are denormalized into folder suggestion for worker context; `email_labels` is the frontend-facing source of truth
- Remaining Tier 2 skills still run in parallel
- No regression: emails without folder suggestions (bootstrap blocked, low confidence) still process correctly

---

### Step 8: Sandbox — New Actions with Specified Implementations

**Files:**
- MODIFY `lib/kontor/ai/sandbox.ex`

**Changes:**

1. Add to `@allowed_actions` MapSet: `:apply_labels`, `:update_sender_rule`
   - Note: `:record_correction` is NOT added to Sandbox — user-initiated corrections bypass the Sandbox and call `Mail.record_folder_correction/4` directly from the controller (authenticated via `AuthenticateTenant` plug).

2. Add `do_execute/3` function heads:

```
defp do_execute(:apply_labels, %{email_id: email_id, labels: labels} = params, tenant_id) do
  attrs = %{
    email_id: email_id,
    labels: labels,
    priority_score: Map.get(params, :priority_score),
    has_actionable_task: Map.get(params, :has_actionable_task, false),
    ai_confidence: Map.get(params, :confidence),
    ai_reasoning: Map.get(params, :reasoning)
  }
  Kontor.Mail.upsert_email_labels(attrs, tenant_id)
end
# Returns {:ok, %EmailLabel{}} | {:error, changeset}

defp do_execute(:update_sender_rule, %{mailbox_id: mailbox_id, sender_pattern: pattern} = params, tenant_id) do
  attrs = %{
    mailbox_id: mailbox_id,
    sender_pattern: pattern,
    rule_type: Map.get(params, :rule_type, "folder_override"),
    rule_data: Map.get(params, :rule_data, %{}),
    confidence: Map.get(params, :confidence, "tentative"),
    source: Map.get(params, :source, "system_detected"),
    active: Map.get(params, :active, true),
    tenant_id: tenant_id
  }
  Kontor.Mail.upsert_sender_rule(attrs, tenant_id)
end
# Returns {:ok, %SenderRule{}} | {:error, changeset}
```

3. Update `FolderOrganizerWorker` to handle `labels` field in folder suggestions. After applying a folder move, read `suggestion.labels` for logging/context. Worker does not crash if `labels` is nil (backward compatibility).

**Acceptance criteria:**
- `Sandbox.allowed_actions` includes `:apply_labels` and `:update_sender_rule` (NOT `:record_correction`)
- Each `do_execute/3` head pattern-matches on the required params and delegates to the correct `Mail` context function
- `apply_labels` passes attrs WITHOUT tenant_id embedded (tenant_id passed as second arg to `upsert_email_labels/2`)
- Missing optional params default gracefully (no `FunctionClauseError`)
- Error returns are `{:error, changeset}` or `{:error, reason}` — never bare raises
- `FolderOrganizerWorker` handles nil `labels` without crash

---

### Step 9: Correction Tracking Endpoint and Background Workers

**Files:**
- CREATE `lib/kontor_web/controllers/api/v1/folder_correction_controller.ex` — new Phoenix controller
- CREATE `lib/kontor/mail/sender_rule_promotion_worker.ex` — Oban worker (daily)
- CREATE `lib/kontor/mail/newsletter_engagement_worker.ex` — Oban worker (daily)
- MODIFY `lib/kontor_web/router.ex` — add route for correction endpoint
- MODIFY `config/config.exs` — add Oban queue config and crontab entries

**Correction Tracking Endpoint:**
- `POST /api/v1/mailboxes/:mailbox_id/folder_corrections`
- Called by the frontend when a user manually moves an email to a different folder
- Request body: `{ "email_id": "...", "from_folder": "...", "to_folder": "..." }`
- Controller looks up the email to extract sender/sender_domain, then calls `Mail.record_folder_correction/4` **directly** (not through Sandbox — user-initiated actions are already authenticated via `AuthenticateTenant` plug; routing through Sandbox would conflate LLM sandboxing with user auth and add unnecessary GenServer serialization)
- Returns `201 Created` with the correction record

**Why corrections come from the frontend (not IMAP polling):** `HimalayaClient` has no `get_email_folder` or equivalent read-path for detecting folder moves. The frontend is the only place that knows when a user manually moves an email.

**SenderRulePromotionWorker (renamed from FolderCorrectionWorker):**
- Runs daily via Oban cron
- For each mailbox, queries `folder_corrections` grouped by sender
- If any sender has >= 3 corrections to the same target folder, upserts a `SenderRule` with confidence "confident"
- This is a promotion worker, not a detection worker — corrections are already recorded via the API endpoint

**NewsletterEngagementWorker:**
- Runs daily via Oban cron
- For each mailbox, checks emails from known newsletter senders (identified by `email_labels.labels` containing "Newsletter")
- If 2+ consecutive emails are unread, sets `auto_archive: true` via `update_newsletter_engagement/3`

**Oban config changes in `config/config.exs`:**
- No new queues needed — both workers can run on the existing `folder_organizer: 2` queue (consistent with existing folder operation workers) or `:default` queue; executor should choose based on load characteristics
- **Append** the two new crontab entries to the existing `crontab` list in `config/config.exs` — do NOT remove the existing `FolderOrganizerWorker` crontab entry at `{"0 23 * * *", Kontor.Mail.FolderOrganizerWorker}`:
  - `{"0 2 * * *", Kontor.Mail.SenderRulePromotionWorker}` (daily at 2am)
  - `{"0 3 * * *", Kontor.Mail.NewsletterEngagementWorker}` (daily at 3am)

**Acceptance criteria:**
- `POST /api/v1/mailboxes/:mailbox_id/folder_corrections` creates a correction record and returns 201
- After 3 corrections from sender X to folder Y, `SenderRulePromotionWorker` creates a "confident" rule
- `NewsletterEngagementWorker` correctly counts consecutive unread newsletters using labels (not category)
- Both workers are registered in Oban config with correct queues and crontab entries

---

### Step 10: API Endpoint for Labels

**Files:**
- CREATE `lib/kontor_web/controllers/api/v1/email_label_controller.ex` (or add action to existing email controller)
- MODIFY `lib/kontor_web/router.ex` — add route

**Endpoint:**
- `GET /api/v1/emails/:id/labels` — returns the `EmailLabel` record for the given email
- Response: `{ "labels": ["Receipt", "VIP"], "priority_score": 72, "has_actionable_task": true, "confidence": 0.88, "reasoning": "..." }`
- Returns 404 if no labels exist for the email
- Scoped to tenant_id from auth context

**Acceptance criteria:**
- Endpoint returns the `EmailLabel` data from the `email_labels` table (source of truth)
- Returns 404 when no label record exists
- Tenant scoping is enforced

---

### Step 11: SkillLoader `active` Flag Support

**Files:**
- MODIFY `lib/kontor/ai/skill_loader.ex`

**Changes:**
- In `load_skill/2` (line 42-48): after parsing the skill content, check if `skill.frontmatter["active"] == false`. If so, return `{:error, :not_found}`.
- When building the Tier 2 skill list in `run_tier2`, skills with `active: false` are automatically excluded because `load_skill` returns `{:error, :not_found}`.

**Acceptance criteria:**
- A skill with `active: false` in frontmatter is not loaded by `load_skill/2`
- Deprecated skills (scorer) can be deactivated by setting `active: false` in frontmatter
- Skills without an `active` key default to active (backward compatible)

---

## Test Plan

### New Test Files

| Test File | Covers |
|-----------|--------|
| `test/kontor/mail/email_label_test.exs` | `EmailLabel` changeset validations: labels array type, priority_score 0-100 range, has_actionable_task boolean, ai_confidence float range |
| `test/kontor/mail/sender_rule_test.exs` | `SenderRule` changeset validations: rule_type inclusion, confidence inclusion, unique constraint on [mailbox_id, sender_pattern]. Promotion logic: 3 corrections -> confident rule |
| `test/kontor/mail/folder_correction_test.exs` | `FolderCorrection` changeset validations. `record_folder_correction/4` creates record and triggers `maybe_promote_sender_rule/3` |
| `test/kontor/mail/newsletter_engagement_test.exs` | `consecutive_unread` increment/reset logic. `auto_archive` set to true after 2 consecutive unreads. Reset on read. |
| `test/kontor/ai/skill_loader_active_flag_test.exs` | `SkillLoader.load_skill/2` returns `{:error, :not_found}` for skills with `active: false` in frontmatter. Skills without `active` key default to active (backward compatible). |
| `test/kontor/ai/pipeline_labeler_test.exs` | Labeler skill routing in Tier 2. `post_process/4` handling of labeler results -> `apply_labels` sandbox action. Tier 1 `priority_score` stored in `email_labels`/`folder_suggestions` only (not in thread scores). Scorer Tier 2 still runs and persists 4-dimensional scores unchanged. |
| `test/kontor_web/controllers/api/v1/email_label_controller_test.exs` | `GET /api/v1/emails/:id/labels`: 200 with label data, 404 when no label record, tenant scoping enforced. |
| `test/kontor/ai/pipeline_folder_organizer_test.exs` | `post_process/4` folder_organizer handling: folder_organizer Tier 2 result creates a `FolderSuggestion` with `status: "pending"`. Field mapping verified: `result["folder"]` → `suggested_folder`, etc. Progressive guards block `create_if_missing: true` when folder cap is reached. Labels from labeler are denormalized into the suggestion. No suggestion created when bootstrap_blocked. |
| `test/kontor_web/controllers/api/v1/folder_correction_controller_test.exs` | `POST /api/v1/mailboxes/:id/folder_corrections`: 201 on success, 422 on invalid params, 404 on missing mailbox. Tenant scoping. Controller calls `Mail.record_folder_correction/4` directly (not through Sandbox). |

---

## Rollback Plan

If Phase 1 degrades email processing quality:

1. **Deactivate labeler skill:** Set `active: false` in `labeler.md` frontmatter. `SkillLoader.load_skill("labeler", "shared")` returns `{:error, :not_found}`, so labeler is never invoked by the pipeline.
2. **Revert classifier:** Restore `classifier.md` to the previous version (available in `SkillVersion` table or git history). Tier 1 output reverts to original fields only (no `priority_score`, no `has_actionable_task`).
3. **Folder organizer fallback:** `folder_organizer.md` retains backward-compatible `structural_category` model as default. If action-based model causes issues, revert the skill file AND revert the `post_process/4` folder_organizer handling in `pipeline.ex` back to parsing the old nested `folder_action` schema (`result["folder_action"]["target_folder"]`), or add a compatibility shim that handles both flat and nested formats. **These two rollbacks must be done together** — reverting only the skill file leaves `post_process/4` trying to read `result["folder"]` which will be nil on the old nested output, silently creating suggestions with `suggested_folder: nil`.
4. **Scorer:** No action needed — scorer is unchanged throughout Phase 1 and continues running as a Tier 2 skill.
5. **New DB tables remain:** All 4 new tables (`email_labels`, `sender_rules`, `folder_corrections`, `newsletter_engagement`) are additive. No data loss or schema conflicts from keeping them. New columns on `folder_suggestions` and `mailboxes` have nullable/default values.

---

## Error Handling Strategy

**Tier 1 classifier returns valid JSON but missing new fields:**
- Missing `priority_score`: default to `50` (middle of range), log warning `"Classifier missing priority_score, defaulting to 50"`
- Missing `has_actionable_task`: default to `false`, skip task pre-signal, log warning

**Labeler Tier 2 skill failure:**
- If labeler returns `{:error, _}` or invalid JSON: skip label persistence for that email
- Do NOT block other Tier 2 results (labeler runs in parallel — its failure is isolated)
- Log warning with email_id for debugging
- Folder suggestion is created without labels (empty array default)

**Sandbox action failures:**
- `:apply_labels` changeset error: log error, do not retry (labels are non-critical)
- `:record_correction` changeset error: return 422 to frontend with validation errors
- `:update_sender_rule` changeset error: log error, promotion worker retries on next daily run

**Folder organizer with missing labels input:**
- If labeler did not run or failed, folder_organizer receives empty labels array
- Folder decision is still made based on email content and other signals

---

## Files Affected Summary

| File | Action | Step |
|------|--------|------|
| `priv/repo/migrations/YYYYMMDD000001_upgrade_folder_organization.exs` | CREATE | 1 |
| `lib/kontor/mail/email_label.ex` | CREATE | 2 |
| `lib/kontor/mail/sender_rule.ex` | CREATE | 2 |
| `lib/kontor/mail/folder_correction.ex` | CREATE | 2 |
| `lib/kontor/mail/newsletter_engagement.ex` | CREATE | 2 |
| `lib/kontor/mail/folder_suggestion.ex` | MODIFY | 2 |
| `lib/kontor/accounts/mailbox.ex` | MODIFY | 2 |
| `lib/kontor/mail/mail.ex` | MODIFY | 3 |
| `priv/skills/shared/classifier.md` | MODIFY (enrich output) | 4 |
| `priv/skills/shared/labeler.md` | CREATE | 5 |
| `priv/skills/shared/folder_organizer.md` | MODIFY (rewrite for action-based) | 6 |
| `priv/skills/shared/scorer.md` | NO CHANGE — scorer continues unchanged as Tier 2 | — |
| `lib/kontor/ai/pipeline.ex` | MODIFY (significant) | 7 |
| `lib/kontor/ai/sandbox.ex` | MODIFY | 8 |
| `lib/kontor/mail/folder_organizer_worker.ex` | MODIFY | 8 |
| `lib/kontor/ai/skill_loader.ex` | MODIFY | 11 |
| `lib/kontor_web/controllers/api/v1/folder_correction_controller.ex` | CREATE | 9 |
| `lib/kontor/mail/sender_rule_promotion_worker.ex` | CREATE | 9 |
| `lib/kontor/mail/newsletter_engagement_worker.ex` | CREATE | 9 |
| `lib/kontor_web/router.ex` | MODIFY | 9, 10 |
| `config/config.exs` | MODIFY (Oban queues + crontab) | 9 |
| `lib/kontor_web/controllers/api/v1/email_label_controller.ex` | CREATE | 10 |
| `test/kontor/mail/email_label_test.exs` | CREATE | Test |
| `test/kontor/mail/sender_rule_test.exs` | CREATE | Test |
| `test/kontor/mail/folder_correction_test.exs` | CREATE | Test |
| `test/kontor/mail/newsletter_engagement_test.exs` | CREATE | Test |
| `test/kontor/ai/skill_loader_active_flag_test.exs` | CREATE | Test |
| `test/kontor/ai/pipeline_labeler_test.exs` | CREATE | Test |
| `test/kontor_web/controllers/api/v1/email_label_controller_test.exs` | CREATE | Test |
| `test/kontor/ai/pipeline_folder_organizer_test.exs` | CREATE | Test |
| `test/kontor_web/controllers/api/v1/folder_correction_controller_test.exs` | CREATE | Test |

**Total: 13 modified, 15 created, 0 deleted**

---

## Global Acceptance Criteria

1. `mix test` passes with no regressions
2. A new email processed through the pipeline produces: a `folder_suggestion` with labels and priority_score, an `email_label` record, and (if actionable) a task
3. Tier 1 classifier remains headers-only — no body content in classifier input
4. `priority_score` from Tier 1 is stored in `email_labels.priority_score` and `folder_suggestions.priority_score` only; scorer Tier 2 skill continues to run and its 4-dimensional thread scores are unaffected
5. Bootstrap guard still blocks folder suggestions when `folder_bootstrap_count < 50`
6. After 3 manual corrections from the same sender (recorded via API endpoint), a confident `sender_rule` exists and subsequent emails from that sender use the rule
7. Newsletter senders (identified by `email_labels.labels` containing "Newsletter") with 2+ consecutive unread emails get `auto_archive: true`
8. No more than 12 active folders can be created per mailbox (progressive guard)
9. Folder creation only happens when weekly volume >= 5 AND confidence >= 0.80
10. Skills with `active: false` in frontmatter are not loaded by `SkillLoader`
11. Missing `priority_score` from classifier defaults to 50; missing `has_actionable_task` defaults to false
12. Labeler failure does not block other Tier 2 skill results

---

## Open Questions

See `.omc/plans/open-questions.md` for tracked items.
