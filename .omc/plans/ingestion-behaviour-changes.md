# Plan: Ingestion Behaviour Changes (Revised — Post Architect/Critic Review)

**Date:** 2026-04-07
**Status:** Final — ready for implementation
**Supersedes:** Draft v1 (pre-review)

---

## Context

Three targeted changes to the email ingestion pipeline in the Kontor Elixir/Phoenix application:

1. Newest-first ingestion in both Poller and Importer via a `sort` param on `HimalayaClient.list_emails`.
2. Task age cutoff: skip `task_extractor` skill for emails older than `mailbox.task_age_cutoff_months` (default 3).
3. Thread completeness: when a new email arrives in the Poller, fetch and upsert all sibling emails in the same thread.

**Pre-existing bug also fixed in this plan:** `poller.ex:30` queries `m.active == true` but the `Mailbox` schema has no `active` field and the DB column does not exist. This would cause a compile-time or runtime error on the first poll. A migration and schema field are added here.

---

## Guardrails

**Must Have**
- Oldest emails are still classified and summarised — only `task_extractor` is gated by age.
- Thread completeness upsert uses `on_conflict: :nothing` — never overwrites existing rows.
- `HimalayaClient.list_emails/3` arity remains valid for all existing callers (new `sort` arg is additive).
- `run_tier2` keeps `tenant_id` as its third positional parameter.
- `import_folder` arity is 6 — not reduced.
- `handle_call` for `list_emails` uses a new 5-tuple clause; the existing 4-tuple clause is preserved for backward compatibility within the GenServer.
- Thread sibling fetch uses `Task.start` (fire-and-forget) — must not block the GenServer with `Task.async`/`Task.await`.
- `MarkdownBackfillWorker` loads the email's mailbox from DB and passes `task_age_cutoff_months` as opts.
- `Enum.filter` (not `Enum.take_while`) used in Importer for age cutoff — server sort is not trusted for correctness.
- All changes covered by ExUnit tests following the existing `async: true` / `DataCase` pattern.

**Must NOT Have**
- No DB read for mailbox inside `Pipeline.do_process` — cutoff value is passed as data via opts.
- No `try/rescue` wrapper around Himalaya sort — use real two-call fallback (try with sort, retry without on error).
- No architecture redesign — all changes are confined to the six files listed below.

---

## Files Touched

| File | Change type |
|---|---|
| `lib/kontor/accounts/mailbox.ex` | Add `:active` field |
| `priv/repo/migrations/20260407000005_add_active_to_mailboxes.exs` | New migration |
| `lib/kontor/mcp/himalaya_client.ex` | Add sort param + two-call fallback |
| `lib/kontor/mail/poller.ex` | Newest-first, opts threading, thread completeness |
| `lib/kontor/mail/importer.ex` | Newest-first, opts threading (pipeline opts via MarkdownBackfillWorker) |
| `lib/kontor/ai/pipeline.ex` | `run_tier2/4` signature, task age cutoff filter |
| `lib/kontor/mail/markdown_backfill_worker.ex` | Load mailbox, pass opts to `process_email` |

---

## Task Flow

---

### Step 1 — Fix pre-existing bug: add `active` field to Mailbox

**Files:**
- `lib/kontor/accounts/mailbox.ex`
- `priv/repo/migrations/20260407000005_add_active_to_mailboxes.exs`

#### 1a. Schema — `lib/kontor/accounts/mailbox.ex`

**Current state (lines 8–22):** The `schema "mailboxes"` block has no `active` field. The changeset cast list has no `:active`. The poller at line 30 queries `where: m.active == true`, which references a non-existent field.

**New behaviour:** Add `:active` as a boolean field with `default: true` to both the schema and the changeset.

Exact insertion point — after `field :copy_emails, :boolean, default: false` (line 16), add:
```elixir
field :active, :boolean, default: true
```

In `changeset/2`, add `:active` to the cast list:
```elixir
|> cast(attrs, [..., :read_only, :copy_emails, :active])
```

**Acceptance criteria:**
- `Kontor.Accounts.Mailbox.__schema__(:fields)` includes `:active`.
- `Mailbox.changeset/2` accepts and casts `%{"active" => false}`.
- Existing test `insert(:mailbox)` continues to compile (new field has a default).

#### 1b. Migration — `priv/repo/migrations/20260407000005_add_active_to_mailboxes.exs`

**New file.** Content:
```elixir
defmodule Kontor.Repo.Migrations.AddActiveToMailboxes do
  use Ecto.Migration

  def change do
    alter table(:mailboxes) do
      add :active, :boolean, default: true, null: false
    end

    create index(:mailboxes, [:active])
  end
end
```

**Acceptance criteria:**
- `mix ecto.migrate` runs without error.
- `mix ecto.rollback` reverts cleanly.
- Existing mailbox rows get `active = true` by default (DB-level default).

---

### Step 2 — Add `sort` param with two-call fallback to `HimalayaClient`

**File:** `lib/kontor/mcp/himalaya_client.ex`

#### Current state

Public function (line 12–14):
```elixir
def list_emails(mailbox, folder \\ "INBOX", limit \\ 50) do
  call({:list_emails, mailbox, folder, limit})
end
```

`handle_call` clause (lines 44–51): matches a 4-tuple `{:list_emails, mailbox, folder, limit}` and calls `mcp_call/2` with a 3-key params map (no `sort`).

There is **no** `try/rescue` anywhere in this file. There is no existing sort-fallback logic.

#### New behaviour

**Public API:** Add `sort \\ "date:desc"` as a fourth optional parameter. When `sort` is non-nil, attempt the MCP call with `sort` included. On any non-success response (`{:error, _}`), retry once without `sort` and log a warning. When `sort` is `nil`, call directly without sort.

**GenServer message shape:** Add a new 5-tuple clause in both `call/1` and `handle_call`. The existing 4-tuple clause must be preserved to avoid breaking any direct `GenServer.call` that could exist outside public API (defensive).

**New public function:**
```elixir
def list_emails(mailbox, folder \\ "INBOX", limit \\ 50, sort \\ "date:desc") do
  call({:list_emails, mailbox, folder, limit, sort})
end
```

**New `handle_call` clause (5-tuple, insert before the existing 4-tuple clause):**
```elixir
@impl true
def handle_call({:list_emails, mailbox, folder, limit, sort}, _from, state) do
  result =
    case mcp_call("himalaya/list_emails", %{mailbox: mailbox, folder: folder,
                                             limit: limit, sort: sort}) do
      {:ok, _} = ok ->
        ok
      {:error, reason} ->
        Logger.warning(
          "HimalayaClient: sort param rejected (#{inspect(reason)}), retrying without sort"
        )
        mcp_call("himalaya/list_emails", %{mailbox: mailbox, folder: folder, limit: limit})
    end
  {:reply, result, state}
end
```

The existing 4-tuple `handle_call` clause is left unchanged.

**Acceptance criteria:**
- `list_emails/3` still compiles and works (default `sort: "date:desc"`, goes through 5-tuple path).
- `list_emails/4` with an explicit sort value sends sort in the MCP params.
- When the 5-tuple path returns `{:error, _}`, the handler retries without sort and logs a warning.
- When the retry also fails, the error is returned to the caller.
- Unit tests:
  - Mock `mcp_call` to return `{:ok, [...]}` on first attempt — assert sort param present in call.
  - Mock `mcp_call` to return `{:error, "unknown param"}` on first attempt, `{:ok, [...]}` on retry — assert warning logged and result is `{:ok, [...]}`.
  - The existing 4-tuple `handle_call` clause still pattern-matches correctly for legacy callers.

---

### Step 3 — Newest-first fetch in Poller and Importer

**Files:** `lib/kontor/mail/poller.ex`, `lib/kontor/mail/importer.ex`

Both files currently call `list_emails` without a sort argument. Because Step 2 adds `sort \\ "date:desc"` as the default, the calls are already effectively newest-first once Step 2 is in place. However, the calls should be explicit for clarity.

#### Poller — `fetch_new_emails/2` (lines 44–49)

**Current:**
```elixir
Kontor.MCP.HimalayaClient.list_emails(mailbox.himalaya_config, "INBOX", 20)
```

**New:**
```elixir
Kontor.MCP.HimalayaClient.list_emails(mailbox.himalaya_config, "INBOX", 20, "date:desc")
```

#### Importer — `import_folder/6` (lines 70–84)

Note: the correct arity is `import_folder/6` (parameters: `mailbox, folder, cutoff, tenant_id, count, total`). The original plan incorrectly referred to it as `/5`.

**Current:**
```elixir
Kontor.MCP.HimalayaClient.list_emails(mailbox.himalaya_config, folder, 200)
```

**New:**
```elixir
Kontor.MCP.HimalayaClient.list_emails(mailbox.himalaya_config, folder, 200, "date:desc")
```

**Age cutoff filter — Importer `import_folder/6` (line 74):**

Keep the existing `Enum.filter` (do not replace with `Enum.take_while`). Server-side sort is a best-effort optimisation; correctness of the cutoff must not depend on it.

**Acceptance criteria:**
- Both call sites pass `"date:desc"` explicitly.
- `Enum.filter` in `import_folder` is not changed to `Enum.take_while`.
- Existing tests that stub `list_emails` with 3-arg arity continue to compile (default covers them).

---

### Step 4 — Pipeline opts threading: `run_tier2/4` + task age cutoff filter

**File:** `lib/kontor/ai/pipeline.ex`

This step and the MarkdownBackfillWorker change (Step 5) are coupled — both deal with threading `task_age_cutoff_months` into the pipeline. They must be implemented together.

#### Current state

`process_email/1` (line 23): reads `tenant_id` from the email struct, casts to `GenServer.cast`.
`process_email/2` (line 27): accepts `email, tenant_id` directly.
`do_process/2` (line 54): calls `run_tier2(email, tier1, tenant_id)`.
`run_tier2/3` (lines 80–94): signature `run_tier2(email, tier1, tenant_id)` — no opts, no age cutoff.

#### New behaviour

**`handle_cast` (line 49):** Update to pass opts from the cast message:
```elixir
def handle_cast({:process_email, email, tenant_id, opts}, state) do
  Task.start(fn -> do_process(email, tenant_id, opts) end)
  {:noreply, state}
end
```

**`process_email/1`** — update cast message to include opts:
```elixir
def process_email(%{tenant_id: tenant_id} = email, opts \\ []) do
  GenServer.cast(__MODULE__, {:process_email, email, tenant_id, opts})
end
```

**`process_email/2`** — add opts with default:
```elixir
def process_email(email, tenant_id, opts \\ []) do
  GenServer.cast(__MODULE__, {:process_email, email, tenant_id, opts})
end
```

Note: existing callers using `process_email(email, tenant_id)` (2-arg form) continue to work because `opts` defaults to `[]`.

**`do_process/3`** — new signature:
```elixir
defp do_process(email, tenant_id, opts) do
  with {:ok, tier1} <- run_classifier(email, tenant_id),
       {:ok, tier2} <- run_tier2(email, tier1, tenant_id, opts) do
    post_process(email, tier1, tier2, tenant_id)
    {:ok, %{tier1: tier1, tier2: tier2, email_id: email.id}}
  end
end
```

**`run_tier2/4`** — new signature, keeping `tenant_id` as third positional param:
```elixir
defp run_tier2(email, tier1, tenant_id, opts \\ []) do
  skill_names    = Map.get(tier1, "tier2_skills", [])
  context_depth  = Map.get(tier1, "context_depth", "full_body")
  cutoff_months  = Keyword.get(opts, :task_age_cutoff_months, 3)

  filtered_skills =
    Enum.reject(skill_names, fn
      "task_extractor" -> not task_extractor_allowed?(email, cutoff_months)
      _other           -> false
    end)

  results =
    filtered_skills
    |> Enum.map(fn name ->
      {name, Task.async(fn -> run_one_tier2(name, email, context_depth, tenant_id) end)}
    end)
    |> Enum.map(fn {name, task} -> {name, Task.await(task, 60_000)} end)
    |> Enum.filter(fn {_name, result} -> match?({:ok, _}, result) end)
    |> Map.new(fn {name, {:ok, result}} -> {name, result} end)

  {:ok, results}
end
```

**New private helper:**
```elixir
defp task_extractor_allowed?(%{received_at: nil}, _cutoff_months), do: true
defp task_extractor_allowed?(%{received_at: received_at}, cutoff_months) do
  cutoff = DateTime.add(DateTime.utc_now(), -(cutoff_months * 30 * 86_400))
  DateTime.compare(received_at, cutoff) != :lt
end
defp task_extractor_allowed?(_email, _cutoff_months), do: true
```

**Acceptance criteria:**
- `run_tier2/3` still compiles as a valid call (default opt covers existing internal callers if any).
- `tenant_id` remains the third positional argument — not dropped.
- `task_extractor` is absent from `filtered_skills` when `email.received_at` is 6 months ago and cutoff is 3 months.
- `thread_summarizer` and `scorer` are unaffected by the filter.
- `received_at: nil` → `task_extractor` retained (treat as "now").
- Unit tests in `test/kontor/ai/pipeline_test.exs`:
  - Email with `received_at` 6 months ago + `opts: [task_age_cutoff_months: 3]` → `task_extractor` filtered.
  - Email with `received_at` 1 month ago + `opts: [task_age_cutoff_months: 3]` → `task_extractor` retained.
  - Email with `received_at: nil` → `task_extractor` retained.
  - Existing `process_email(email, tenant_id)` call form still compiles and runs.

---

### Step 5 — `MarkdownBackfillWorker`: load mailbox, pass opts to pipeline

**File:** `lib/kontor/mail/markdown_backfill_worker.ex`

#### Current state

`process_stale_thread/2` (lines 41–64): When an email with a body is found, calls `Kontor.AI.Pipeline.process_email(email)` — no opts, no mailbox load.

#### New behaviour

Load the email's mailbox and pass `task_age_cutoff_months` as opts:

```elixir
defp process_stale_thread(thread, tenant_id) do
  email =
    Repo.one(
      from e in Email,
      where:
        e.thread_id == ^thread.thread_id and
        e.tenant_id == ^tenant_id and
        not is_nil(e.body),
      order_by: [desc: e.received_at],
      limit: 1
    )

  case email do
    nil ->
      Logger.warning(
        "MarkdownBackfillWorker: thread #{thread.thread_id} (tenant #{tenant_id}) " <>
        "marked stale but no email body available — marking clean to prevent retry loop."
      )
      Mail.mark_thread_processed(thread.thread_id, tenant_id)

    email ->
      mailbox = Repo.get(Kontor.Accounts.Mailbox, email.mailbox_id)
      cutoff = (mailbox && mailbox.task_age_cutoff_months) || 3
      Kontor.AI.Pipeline.process_email(email, [task_age_cutoff_months: cutoff])
  end
end
```

Note: `process_email/2` in the updated pipeline accepts `(email, opts)` when called with a list as the second argument. Because the existing `process_email/2` has the signature `process_email(email, tenant_id)`, the worker must use the form that passes opts via the 1-arg entry point or an explicit 3-arg call. Use the updated `process_email/1` with opts merged onto the email, or use the 3-arg form:

```elixir
Kontor.AI.Pipeline.process_email(email, email.tenant_id, [task_age_cutoff_months: cutoff])
```

This is unambiguous and avoids any confusion with the `process_email(email, tenant_id)` 2-arg form.

**Acceptance criteria:**
- `Repo.get(Kontor.Accounts.Mailbox, email.mailbox_id)` is called for each stale email.
- `task_age_cutoff_months` in the opts equals `mailbox.task_age_cutoff_months || 3`.
- When `mailbox` is nil (deleted between email insert and worker run), defaults to `3` gracefully.
- Unit tests in `test/kontor/mail/markdown_backfill_worker_test.exs`:
  - Assert pipeline receives `[task_age_cutoff_months: N]` where N matches the mailbox value.
  - Assert pipeline receives `[task_age_cutoff_months: 3]` when mailbox has `nil` for the field.

---

### Step 6 — Poller: opts threading + thread completeness fetch

**File:** `lib/kontor/mail/poller.ex`

This step updates two separate concerns in the Poller but they share the same diff context, so they are implemented together.

#### 6a. Fix `poll_all_mailboxes` — `m.active` field (already addressed in Step 1)

`poller.ex:30` queries `where: m.active == true`. After Step 1 adds the `active` field to the schema and DB, this line compiles and works correctly. No change needed to the Poller query itself.

#### 6b. Thread opts threading — two call sites in `process_email/2`

**Current `process_email/2` (lines 51–88):** The `mailbox` struct is in scope. Two pipeline call sites exist:

- Line 74 (stale-thread recheck, duplicate email branch): `Kontor.AI.Pipeline.process_email(existing)`
- Line 82 (new email branch): `Kontor.AI.Pipeline.process_email(email)`

**New behaviour at both call sites:** Pass `task_age_cutoff_months` as opts:

```elixir
# At line 74 — stale thread recheck (existing email)
opts = [task_age_cutoff_months: mailbox.task_age_cutoff_months || 3]
Kontor.AI.Pipeline.process_email(existing, tenant_id, opts)

# At line 82 — new email
opts = [task_age_cutoff_months: mailbox.task_age_cutoff_months || 3]
Kontor.AI.Pipeline.process_email(email, tenant_id, opts)
```

`mailbox` is in scope at both sites: `process_email/2` receives `raw_email` and `mailbox` as parameters.

#### 6c. Thread completeness fetch — fire-and-forget on new email arrival

**Current new-email branch (lines 79–84):**
```elixir
{:ok, %Email{id: _id} = email} ->
  upsert_thread(email, tenant_id)
  Kontor.AI.Pipeline.process_email(email)
  Kontor.Contacts.OrganizationWorker.process_email_contacts(email, tenant_id)
```

**New behaviour:**
```elixir
{:ok, %Email{id: _id} = email} ->
  upsert_thread(email, tenant_id)
  opts = [task_age_cutoff_months: mailbox.task_age_cutoff_months || 3]
  Task.start(fn -> fetch_and_upsert_thread_siblings(email, mailbox, tenant_id) end)
  Kontor.AI.Pipeline.process_email(email, tenant_id, opts)
  Kontor.Contacts.OrganizationWorker.process_email_contacts(email, tenant_id)
```

`Task.start` (fire-and-forget) is used instead of `Task.async`/`Task.await` to avoid blocking the GenServer for up to 5 seconds per email. The pipeline is called immediately after spawning the task — thread completeness and pipeline run concurrently.

**New private function `fetch_and_upsert_thread_siblings/3`:**

```elixir
defp fetch_and_upsert_thread_siblings(email, mailbox, tenant_id) do
  case Kontor.MCP.HimalayaClient.list_emails(
         mailbox.himalaya_config, "INBOX", 100, "date:desc"
       ) do
    {:ok, all_emails} ->
      all_emails
      |> Enum.filter(fn e -> e["thread_id"] == email.thread_id end)
      |> Enum.reject(fn e -> e["id"] == email.message_id end)
      |> Enum.each(fn raw ->
        attrs = %{
          tenant_id: tenant_id,
          mailbox_id: mailbox.id,
          message_id: raw["id"],
          thread_id: raw["thread_id"],
          subject: raw["subject"],
          sender: raw["from"],
          recipients: raw["to"] || [],
          body: raw["body"],
          received_at: parse_dt(raw["date"])
        }
        Repo.insert(
          Email.changeset(%Email{}, attrs),
          on_conflict: :nothing,
          conflict_target: [:tenant_id, :message_id]
        )
      end)

    {:error, reason} ->
      Logger.warning(
        "Poller: thread completeness fetch failed for thread #{email.thread_id}: #{inspect(reason)}"
      )
  end
end
```

**Acceptance criteria:**
- Both poller call sites (stale-thread recheck and new email) pass `[task_age_cutoff_months: ...]` opts to `Pipeline.process_email`.
- `mailbox` is confirmed in scope at both sites (it is a parameter of `process_email/2`).
- Thread sibling fetch runs in a `Task.start` — does not block the GenServer.
- Sibling emails with the same `thread_id` as the triggering email are upserted with `on_conflict: :nothing`.
- The triggering email's `message_id` is excluded from the upsert.
- If `list_emails` returns `{:error, _}`, a warning is logged and processing continues.
- Pipeline is called for the triggering email regardless of sibling fetch outcome.
- No sibling email triggers `Pipeline.process_email`.
- Unit/integration tests in `test/kontor/mail/poller_test.exs` (new file):
  - Mock `HimalayaClient.list_emails` to return 3 emails with the same `thread_id` + 1 with a different thread.
  - Assert 2 new Email rows inserted for siblings (triggering email already present).
  - Assert pipeline called exactly once (for the triggering email only).
  - Assert `{:error, reason}` from `list_emails` → warning logged, pipeline still called.
  - Assert opts passed to pipeline contain `task_age_cutoff_months` equal to mailbox value.

---

## Migration Needed

| Migration file | Purpose |
|---|---|
| `priv/repo/migrations/20260407000005_add_active_to_mailboxes.exs` | Add `active :boolean default true` column + index |

No other schema changes. `task_age_cutoff_months` already exists in both schema and DB (present in `20250101000002_create_mailboxes.exs`).

---

## Test Summary

| Test file | New tests added |
|---|---|
| `test/kontor/accounts/accounts_test.exs` | `Mailbox.changeset` casts `active`; default is `true` |
| `test/kontor/mcp/himalaya_client_test.exs` (new) | `list_emails/4` passes sort; sort-error triggers fallback + warning; fallback returns result |
| `test/kontor/ai/pipeline_test.exs` | 3 age-cutoff tests; `run_tier2` opts threading; existing 2-arg callers still work |
| `test/kontor/mail/markdown_backfill_worker_test.exs` | Worker passes `task_age_cutoff_months` from mailbox; nil mailbox defaults to 3 |
| `test/kontor/mail/poller_test.exs` (new) | Thread completeness: siblings upserted; error path; pipeline called once; opts threading |

All tests: `async: false` for GenServer-touching tests (Poller, Pipeline), `async: true` for pure-logic and Ecto-only tests.

---

## Success Criteria

1. `mix test` passes with zero failures.
2. `mix ecto.migrate` and `mix ecto.rollback` run without error.
3. `HimalayaClient.list_emails/3` still compiles and works (backward-compatible default).
4. `HimalayaClient.list_emails/4` sends `sort` in the MCP params body; falls back silently on error.
5. Poller and Importer both pass `"date:desc"` explicitly to `list_emails`.
6. Pipeline skips `task_extractor` for emails older than the mailbox cutoff; all other skills run normally.
7. On new-email ingestion via Poller, the DB contains rows for all same-thread siblings Himalaya returns, without blocking the GenServer.
8. `MarkdownBackfillWorker` passes per-mailbox `task_age_cutoff_months` to the pipeline.
9. `poller.ex:30` `where: m.active == true` compiles and filters correctly.

---

## RALPLAN-DR Summary

### Principles

1. **Minimal footprint** — change only the code that needs to change; no cross-cutting rewrites.
2. **Data flows down** — the pipeline receives cutoff value as opts rather than re-fetching the mailbox.
3. **Fail-open on completeness** — sibling fetch failures are logged and swallowed; the triggering email is always processed.
4. **Non-destructive upserts** — all Himalaya-sourced inserts use `on_conflict: :nothing`.
5. **Real fallback, not fiction** — the sort fallback is implemented as an actual retry, not a comment claiming try/rescue protects it.

### Decision Drivers (top 3)

1. **No blocking in GenServer** — `Task.start` for thread sibling fetch; `Task.async`/`Task.await` would block up to 5s per email inside the GenServer message loop.
2. **Filter correctness over sort trust** — `Enum.filter` in Importer is non-negotiable; server sort may be unreliable so cutoff enforcement must be client-side.
3. **Additive API changes only** — `list_emails` sort and `run_tier2` opts are both default-arg additions; zero breaking changes to existing callers.

### Viable Options

#### Decision A: Thread sibling fetch — blocking vs fire-and-forget

**Option A1 (chosen): `Task.start` — fire-and-forget, concurrent with pipeline**
- Pro: GenServer is never blocked; poller throughput unaffected.
- Con: Pipeline may start before all siblings are in DB; first-pass thread summary may be incomplete. MarkdownBackfillWorker will re-run if thread is still stale.

**Option A2: Synchronous, before pipeline call (original plan)**
- Pro: Thread is complete before pipeline summarises.
- Con: `Task.async`/`Task.await` inside a GenServer blocks the message queue for up to 5s per email — unacceptable under load.
- Invalidated by Critic: blocks GenServer.

#### Decision B: Where to enforce age cutoff

**Option B1 (chosen): In `run_tier2` via opts, resolved at call sites in Poller + MarkdownBackfillWorker**
- Pro: Pipeline stays data-in/data-out; no DB read inside `do_process`.
- Con: All call sites must supply opts; defended by `|| 3` defaults everywhere.

**Option B2: DB read for mailbox inside `do_process`**
- Pro: Self-contained pipeline.
- Con: Adds a DB read on every email processed; violates data-flows-down principle.
- Invalidated: added latency and coupling.

#### Decision C: Sort fallback strategy

**Option C1 (chosen): Two-call fallback in `handle_call` — try with sort, retry without on error**
- Pro: Real protection against Himalaya rejecting the sort param.
- Pro: Transparent to callers; no API surface change.
- Con: Two MCP round-trips on fallback path (rare).

**Option C2: try/rescue wrapper (original plan claim)**
- Invalidated: `himalaya_client.ex` has no try/rescue; claiming it does is incorrect. The two-call fallback is the correct implementation.

---

## ADR: Ingestion Behaviour Changes

**Decision:** Implement newest-first fetch via explicit `sort` param with two-call fallback; enforce task age cutoff via opts threading through the pipeline; fetch thread siblings fire-and-forget via `Task.start`; add `active` field to Mailbox schema and DB.

**Drivers:**
1. GenServer must not block — fire-and-forget for I/O side-tasks.
2. Cutoff correctness must not rely on server sort order — use `Enum.filter`.
3. All API changes must be additive — no breaking changes to existing callers.
4. Pre-existing `active` field bug must be fixed as a prerequisite to poller correctness.

**Alternatives considered:**
- Synchronous thread completeness fetch — rejected (blocks GenServer).
- DB read for mailbox inside `do_process` — rejected (added latency, wrong layer).
- `try/rescue` for sort fallback — rejected (non-existent in original code; real two-call retry is correct).
- `Enum.take_while` for importer cutoff — rejected (sort unreliable for correctness gate).

**Why chosen:** Each decision resolves a concrete correctness or performance defect identified in Critic review while preserving backward compatibility and the existing module boundaries.

**Consequences:**
- Thread summary on first pass may be slightly incomplete if siblings arrive after the pipeline starts (fire-and-forget trade-off). MarkdownBackfillWorker re-runs on the 5-minute cron.
- Two MCP calls on sort-fallback path (rare, only when Himalaya rejects the param).
- All existing callers of `list_emails`, `process_email`, and `run_tier2` are unaffected by default args.

**Follow-ups:**
- Evaluate adding `list_thread_emails` MCP endpoint once Himalaya supports it — would remove the client-side thread filter and the 100-email over-fetch.
- Consider extending thread completeness to non-INBOX folders (Sent, Archive).
- Consider a configurable `Task.start` timeout/supervision for the sibling fetch task.
