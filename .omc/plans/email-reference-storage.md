# Plan: Email Reference Storage (Reference-First, Copy-Optional) -- REVISED

**Date:** 2026-04-06
**Revision:** 2 (incorporates Architect ITERATE + Critic REVISE feedback)
**Complexity:** MEDIUM
**Scope:** 8 steps across ~15 files (bug fix, ADR, migration, schemas, import pipeline, AI pipeline, Oban worker, frontend, tests)

---

## Context

Kontor stores the full email body and raw headers for every imported email. The AGENTS.md spec describes a "lossy markdown" system where thread markdown is the primary working document. This plan changes the default: after an email is processed by the AI pipeline, its body is conditionally discarded (when `mailbox.copy_emails == false`). The body is always inserted at import time (needed for pipeline processing) and only removed on successful pipeline completion.

**Key revision from v1:** The processing flag moves from Email to Thread (`markdown_stale` on Thread instead of `markdown_processed` on Email). The body lifecycle is inverted: body is always inserted, then conditionally nilled out after successful AI processing. A new Oban worker handles batch processing of stale threads from the Importer path.

---

## RALPLAN-DR Summary

### Principles (5)

1. **Storage minimalism** -- Store the minimum data needed for the AI pipeline to function; markdown is the primary working document.
2. **Process-once guarantee** -- Each email contributes to thread markdown exactly once; enforced by atomic CAS on `threads.markdown_stale`.
3. **Opt-in richness** -- Full body storage is available but not default; the user controls the trade-off via `mailbox.copy_emails`.
4. **Backwards compatibility** -- Existing emails with bodies remain untouched; new behavior applies to newly imported emails only.
5. **Pipeline decoupling** -- The import step and the AI processing step remain separable; body cleanup is a post-processing concern, not an import concern.

### Decision Drivers (Top 3)

1. **Storage cost** -- Email bodies dominate database size; reference-only storage can reduce email table size by 80-90%.
2. **Processing correctness** -- The AI pipeline must reliably process each email exactly once for markdown, enforced by atomic CAS on the thread's `markdown_stale` flag.
3. **User control** -- Some users need full body search/archive; the toggle must be per-mailbox and easy to change.

### Viable Options

#### Option A: Reference-only with per-mailbox copy flag + thread-level stale tracking (CHOSEN)

Insert email WITH body (as today). Run AI pipeline. On success, conditionally nil out body (only when `mailbox.copy_emails == false`). Track processing state via `markdown_stale` boolean on Thread (not Email). Use atomic CAS (`UPDATE threads SET markdown_stale = false WHERE id = ? AND markdown_stale = true`) for concurrency safety.

| Pros | Cons |
|------|------|
| Body always available during pipeline (self-healing on failure) | Two-phase lifecycle (insert with body, then nil out) adds code |
| Thread-level flag simplifies batch reprocessing queries | Body not available for full-text search after cleanup |
| Atomic CAS handles concurrent emails in same thread | Cannot retroactively populate bodies without re-import |
| Backwards compatible migration | Slightly more complex than single-flag approach |

#### Option B: Separate body table with lazy-load

Move `body` and `raw_headers` to a separate `email_bodies` table. Always store metadata in `emails`. Optionally populate `email_bodies` based on mailbox setting.

| Pros | Cons |
|------|------|
| Clean separation of concerns | More complex schema (extra table, joins) |
| Enables per-email body retention | Migration is more invasive |
| Better for future attachment storage | Over-engineered for current needs |

**Why Option B was not chosen:** The current codebase has no attachment handling, no full-text search on bodies, and the email table is the only consumer. A separate table adds schema complexity without proportional benefit at this stage. Option A can be upgraded to Option B later if needed.

---

## Guardrails

### Must Have
- Default behavior: body is discarded AFTER successful markdown processing (not at insert time)
- `copy_emails` boolean on Mailbox (default: false)
- `markdown_stale` boolean on Thread (default: true)
- Body always inserted at import time (self-healing: body preserved on pipeline failure)
- Atomic CAS on `markdown_stale` for concurrency safety
- Migration is backwards compatible (body becomes nullable, existing data untouched)
- Sandbox key mismatch (`:markdown` vs `:content`) fixed as prerequisite
- Nil-id guard on `on_conflict: :nothing` inserts before pipeline calls
- MarkdownBackfillWorker for batch processing of stale threads from Importer path

### Must NOT Have
- No deletion of existing email bodies in migration
- No changes to the Himalaya MCP client interface
- No `email_processing_log` table (deferred to v2)
- No breaking changes to the REST API contract for GET /api/v1/emails/:id (body may be null, frontend handles gracefully)

---

## Task Flow

### Step 0: Fix Sandbox Key Mismatch (Prerequisite)

**Files:**
- `lib/kontor/ai/pipeline.ex` (line 121)
- `lib/kontor/ai/sandbox.ex` (line 98)

**Work:**
1. **Problem:** `pipeline.ex:121` calls `Sandbox.execute(:write_thread_markdown, %{thread_id: email.thread_id, markdown: md}, tenant_id)` passing the key `:markdown`. But `sandbox.ex:98` pattern-matches on `%{thread_id: id, content: content}` -- expecting `:content`. This mismatch means `write_thread_markdown` always falls through to a function clause error. The process-once guarantee depends on `post_process` succeeding, so this must be fixed first.
2. **Fix:** Change the key in `pipeline.ex:121` from `:markdown` to `:content`, OR change `sandbox.ex:98` from `:content` to `:markdown`. Recommended: change `pipeline.ex` to use `:content` to match the Sandbox's established API.
   - `pipeline.ex:121`: `%{thread_id: email.thread_id, markdown: md}` becomes `%{thread_id: email.thread_id, content: md}`

**Acceptance Criteria:**
- [ ] `Sandbox.execute(:write_thread_markdown, %{thread_id: id, content: "test"}, tenant_id)` matches the correct `do_execute` clause
- [ ] Pipeline `post_process/4` successfully writes thread markdown end-to-end (manual or test verification)

---

### Step 1: ADR + Migration

**Files:**
- `MODIFY .archgate/adrs/ARCH-006-email-reference-storage.md` (updated ADR)
- `NEW priv/repo/migrations/2026MMDD000001_add_email_reference_storage.exs`

**Work:**
1. Update the ADR file to reflect all revised decisions (see companion ADR file).
2. Create a single migration that:
   - Adds `copy_emails` boolean to `mailboxes` table (default: `false`, null: `false`)
   - Alters `body` column on `emails` to allow NULL (`alter table(:emails) do modify :body, :text, null: true end`)
   - Alters `raw_headers` column on `emails` to allow NULL (`modify :raw_headers, :map, null: true, default: nil`)
   - Adds `markdown_stale` boolean to `threads` table (default: `true`, null: `false`)
   - Adds partial index: `CREATE INDEX threads_stale_idx ON threads (tenant_id) WHERE markdown_stale = true`
3. Do NOT add `markdown_processed` to emails (removed per Architect review).

**Acceptance Criteria:**
- [ ] `mix ecto.migrate` runs without errors
- [ ] `mix ecto.rollback` undoes all changes cleanly
- [ ] Existing emails with body data are unaffected
- [ ] New emails can be inserted with `body: nil`
- [ ] Existing threads get `markdown_stale: true` (migration default)
- [ ] Partial index exists on `threads` for `markdown_stale = true`
- [ ] ADR follows the ARCH-001 format

---

### Step 2: Schema Updates (Mailbox + Email + Thread)

**Files:**
- `lib/kontor/accounts/mailbox.ex`
- `lib/kontor/mail/email.ex`
- `lib/kontor/mail/thread.ex`

**Work:**
1. **Mailbox schema:** Add `field :copy_emails, :boolean, default: false`. Add `:copy_emails` to the `cast` list in `changeset/2`.
2. **Email schema:** No new fields needed. Confirm `body` and `raw_headers` are not in `validate_required` (they are not -- verified). The existing `processed_at` field is already present and will be used as an audit timestamp.
3. **Thread schema:** Add `field :markdown_stale, :boolean, default: true`. Add `:markdown_stale` to the `cast` list in `changeset/2`.

**Acceptance Criteria:**
- [ ] `Mailbox.changeset(%Mailbox{}, %{copy_emails: true})` accepts the field
- [ ] `Email.changeset(%Email{}, %{body: nil})` passes validation
- [ ] `Thread.changeset(%Thread{}, %{markdown_stale: false})` accepts the field
- [ ] Existing tests continue to pass

---

### Step 3: Import Flow -- Body Always Inserted, Nil-ID Guard

**Files:**
- `lib/kontor/mail/poller.ex` (lines 47-67, `process_email/2`)
- `lib/kontor/mail/importer.ex` (lines 81-99, `import_email/3`)

**Work:**

1. **Poller `process_email/2`:**
   - Body is inserted as-is (no change to attrs construction -- body always stored at insert time).
   - After `Repo.insert` with `on_conflict: :nothing`: check that the returned email has a non-nil `id`. If `id` is nil (duplicate), fetch the existing email by `[tenant_id: tenant_id, message_id: attrs.message_id]`. Then check the thread: only call `Pipeline.process_email/1` if the thread's `markdown_stale == true`.
   - When a new email is inserted (non-nil id): upsert the Thread record to guarantee it exists and has `markdown_stale = true`. Use:
     ```
     INSERT INTO threads (tenant_id, thread_id, markdown_stale, last_updated)
     VALUES (?, ?, true, now())
     ON CONFLICT (tenant_id, thread_id) DO UPDATE SET markdown_stale = true
     ```
     In Ecto: `Repo.insert(Thread.changeset(%Thread{}, attrs), on_conflict: [set: [markdown_stale: true]], conflict_target: [:tenant_id, :thread_id])`. This guarantees a Thread row exists for the BackfillWorker to query.

2. **Importer `import_email/3`:**
   - Body is inserted as-is (no change -- body always stored at insert time).
   - Add the same nil-id guard: if `on_conflict: :nothing` returns `%Email{id: nil}`, fetch existing email by `[tenant_id: tenant_id, message_id: attrs.message_id]`.
   - Do NOT call `Pipeline.process_email/1` from the Importer. Instead, the Importer relies on the `MarkdownBackfillWorker` (Step 5) to process stale threads in batches. This keeps the Importer's rate-limited bulk import path simple.
   - On successful insert of a genuinely new email (non-nil id): perform the same Thread upsert as the Poller to ensure the Thread row exists with `markdown_stale = true`.

3. **Both flows — thread upsert is mandatory:** Thread records are currently created lazily only by `mail.ex:49-52` (inside the pipeline's Sandbox call). Since the Importer never calls the pipeline, without an explicit upsert the MarkdownBackfillWorker would never find a Thread row to process. The upsert in both flows closes this gap.

**Acceptance Criteria:**
- [ ] Email row is always inserted with body (regardless of `copy_emails` setting)
- [ ] When `on_conflict: :nothing` returns nil id, the existing email is fetched and pipeline is only called if `thread.markdown_stale == true`
- [ ] New email insertion sets `thread.markdown_stale = true` on the corresponding thread
- [ ] Importer does NOT call `Pipeline.process_email/1` directly
- [ ] Poller calls `Pipeline.process_email/1` only when `thread.markdown_stale == true`
- [ ] `on_conflict: :nothing` dedup by `[tenant_id, message_id]` still works correctly
- [ ] Import progress broadcasting is unchanged

---

### Step 4: AI Pipeline -- Markdown Stale CAS, Body Cleanup, Error Handling

**Files:**
- `lib/kontor/ai/pipeline.ex` (lines 48-59, `do_process/2` and `post_process/4`)
- `lib/kontor/mail/mail.ex` (new functions)

**Work:**

1. **Pipeline `post_process/4`:** After successfully updating thread markdown via Sandbox, perform an atomic CAS using `thread_id` (string) + `tenant_id` — NOT the PK `id` — to match the existing lookup pattern in `mail.ex:47`:
   ```
   Repo.update_all(
     from(t in Thread, where: t.thread_id == ^thread_id and t.tenant_id == ^tenant_id and t.markdown_stale == true),
     set: [markdown_stale: false]
   )
   ```
   `Repo.update_all` returns `{n, nil}` (bare tuple, NOT `{:ok, ...}`). The wrapper `mark_thread_processed/1` translates: `{1, nil} → {:ok, :updated}`, `{0, nil} → {:ok, :already_processed}`. If `{0, nil}`, another process won the race — skip body cleanup.

2. **Body cleanup in `post_process/4` success path:** After the CAS succeeds (1 row updated), preload the email's mailbox and check `mailbox.copy_emails`. If `false`, nil out the email's body and raw_headers:
   ```
   email |> Email.changeset(%{body: nil, raw_headers: nil}) |> Repo.update()
   ```
   Also set `processed_at: DateTime.utc_now()` on the email as an audit timestamp.

3. **Error handling:** Wrap the `post_process/4` logic in `try/rescue`. On any failure (Sandbox error, CAS failure, body cleanup failure), log the error and leave the body intact. The email body is preserved, and `markdown_stale` remains `true` on the thread, allowing the `MarkdownBackfillWorker` to retry later. This is the self-healing property.

4. **Mail context:** Add helper functions:
   - `mark_thread_processed/2` -- accepts `thread_id` (string) and `tenant_id`; runs atomic CAS via `Repo.update_all` (returns `{n, nil}`); wraps to `{:ok, :updated}` or `{:ok, :already_processed}`
   - `clear_email_body/1` -- sets `body: nil, raw_headers: nil, processed_at: now` on the email
   - `stale_threads/2` -- query for threads with `markdown_stale = true` for a given tenant, with limit option (used by backfill worker)

**Acceptance Criteria:**
- [ ] After successful pipeline run, `thread.markdown_stale` is set to `false` via atomic CAS
- [ ] When `mailbox.copy_emails == false`, email body is nilled out after successful processing
- [ ] When `mailbox.copy_emails == true`, email body is preserved after processing
- [ ] On pipeline failure, email body remains intact and `thread.markdown_stale` remains `true`
- [ ] Concurrent emails in the same thread: CAS loser sees 0 rows updated and skips body cleanup
- [ ] `processed_at` timestamp is set on the email after successful processing
- [ ] Pipeline works with existing email struct (no tuple changes needed -- body is on the struct at pipeline time)

---

### Step 5: MarkdownBackfillWorker (Oban)

**Files:**
- `NEW lib/kontor/mail/markdown_backfill_worker.ex`
- `lib/kontor/application.ex` (add Oban queue config if needed)
- `config/config.exs` (add `:markdown_backfill` queue)

**Work:**

1. **New Oban worker:** `Kontor.Mail.MarkdownBackfillWorker`
   - Queue: `:markdown_backfill`, max_attempts: 3
   - Uses `Oban.Plugins.Cron` (5-minute interval); Oban deduplicates cron slots natively
   - `perform/1`:
     a. Query for threads with `markdown_stale = true`, limit 50, ordered by `updated_at ASC`
     b. For each stale thread, find the most recent email with a non-nil body (`WHERE thread_id = ? AND body IS NOT NULL ORDER BY received_at DESC LIMIT 1`)
     c. **Body-nil guard:** If no email with non-nil body is found for a stale thread (all bodies already cleaned or thread has no emails), set `markdown_stale = false` and log a warning: "Thread {id} marked stale but no email body available — marking clean to prevent retry loop." Skip pipeline for this thread.
     d. Call `Pipeline.process_email/1` for the found email
     e. The pipeline's `post_process/4` handles the CAS and body cleanup as defined in Step 4
   - Also schedule one run on application startup (enqueue the first job in `application.ex`)

2. **Oban config:** Add `:markdown_backfill` queue with concurrency 2 to `config/config.exs`:
   ```
   queues: [default: 5, mailer: 3, markdown_backfill: 2]
   ```

3. **Cron schedule:** Add to Oban plugins:
   ```
   {Oban.Plugins.Cron, crontab: [{"*/5 * * * *", Kontor.Mail.MarkdownBackfillWorker}]}
   ```

**Acceptance Criteria:**
- [ ] Worker runs every 5 minutes and processes stale threads
- [ ] Worker processes threads in oldest-first order
- [ ] Worker respects the CAS -- does not reprocess threads already being processed
- [ ] Worker is scheduled on startup
- [ ] Worker handles empty result set gracefully (no stale threads = no-op)
- [ ] Oban queue `:markdown_backfill` is configured with concurrency 2

---

### Step 6: AGENTS.md Updates + Frontend

**Files:**
- `AGENTS.md` (lines 93 and 171)
- `frontend/src/stores/mailboxes.js` (add `updateMailbox` action)
- `NEW frontend/src/components/MailboxSettings.vue` (or integrate into existing mailbox UI)

**Work:**

1. **AGENTS.md line 93:** Change `"Raw preservation": All emails always in PostgreSQL; markdown is lossy working document` to: `"Body lifecycle": Email bodies inserted at import, conditionally discarded after AI processing (per mailbox.copy_emails setting); markdown is the primary working document`

2. **AGENTS.md line 171:** Change `5. Raw emails always preserved in PostgreSQL` to: `5. Email bodies conditionally discarded after AI processing (retained when mailbox.copy_emails = true)`

3. **Pinia store:** Add an `updateMailbox` action that calls `PATCH /api/v1/mailboxes/:id` with updated attrs.

4. **MailboxSettings component:** Create a settings panel with:
   - `copy_emails` toggle (checkbox/switch) with label: "Store full email bodies"
   - Helper text: "When disabled, email bodies are used for AI processing then discarded to save storage."
   - Save button that calls `updateMailbox`

5. **Null body handling:** Ensure that `GET /api/v1/emails/:id` returning `body: null` is handled gracefully in the frontend email detail view. Show "Body not stored -- email content was used for AI processing but not retained." message when body is null.

**Acceptance Criteria:**
- [ ] AGENTS.md lines 93 and 171 reflect the new body lifecycle policy
- [ ] Toggle is visible in mailbox settings UI
- [ ] Changing toggle and saving updates the mailbox record in the database
- [ ] Default value for new mailboxes shows as "off" (unchecked)
- [ ] Email detail view handles `body: null` gracefully with informative message
- [ ] Toggle state persists across page reloads

---

### Step 7: Tests

**Files:**
- `test/kontor/ai/pipeline_test.exs` (new or extend)
- `test/kontor/mail/poller_test.exs` (new or extend)
- `test/kontor/mail/importer_test.exs` (new or extend)
- `test/kontor/mail/markdown_backfill_worker_test.exs` (new)
- `test/kontor/accounts/accounts_test.exs` (extend)
- `frontend/src/__tests__/stores/mailboxes.test.js` (extend)

**Work:**

1. **Sandbox key fix test:** Verify `Sandbox.execute(:write_thread_markdown, %{thread_id: id, content: md}, tid)` succeeds (Step 0 regression test).

2. **Pipeline CAS test:** Verify that after processing, `thread.markdown_stale` is `false`. Verify that a second call for the same thread returns `{:ok, :already_processed}` from the CAS.

3. **Body cleanup test (copy_emails=false):** After pipeline success, verify email body is `nil` and `processed_at` is set.

4. **Body preservation test (copy_emails=true):** After pipeline success, verify email body is still present.

5. **Failure/recovery test:** Simulate pipeline failure (e.g., Sandbox returns error). Verify: email body remains intact, `thread.markdown_stale` remains `true`, backfill worker will pick it up on next run.

6. **Nil-id guard test:** Insert a duplicate email (`on_conflict: :nothing`). Verify: returned struct has nil id, code fetches existing email, pipeline is only called if `thread.markdown_stale == true`.

7. **Backfill worker test:** Insert emails via Importer (no pipeline call). Verify `markdown_stale == true` on thread. Run worker. Verify `markdown_stale == false` after worker completes.

8. **Accounts test:** Verify `copy_emails` field is accepted in mailbox changeset and persisted.

9. **Frontend test:** Verify the `updateMailbox` action calls the correct API endpoint. Verify null body display.

**Acceptance Criteria:**
- [ ] All new tests pass
- [ ] Existing test suite passes without modification (backwards compat)
- [ ] Minimum coverage: copy_emails=false path, copy_emails=true path, process-once CAS, failure/recovery, nil-id guard, backfill worker batch processing
- [ ] No flaky tests from race conditions (CAS tests use deterministic setup)

---

## Success Criteria

1. **Sandbox fix verified** -- `pipeline.ex` passes `:content` key matching `sandbox.ex` pattern (Step 0)
2. **Body lifecycle correct** -- Body always inserted at import, conditionally nilled after successful pipeline processing
3. **Process-once via CAS** -- Atomic `UPDATE threads SET markdown_stale = false WHERE id = ? AND markdown_stale = true` prevents duplicate processing
4. **Self-healing on failure** -- Pipeline failure leaves body intact and `markdown_stale = true` for retry
5. **Backfill worker operational** -- Importer-imported emails are processed by `MarkdownBackfillWorker` on 5-minute interval
6. **Concurrent safety** -- Two emails arriving for the same thread: CAS loser skips, winner's markdown incorporates latest context
7. **Migration backwards compatible** -- Existing email rows retain body data, existing threads get `markdown_stale: true`
8. **Frontend handles null body** -- Email detail view shows informative message when `body: null`
9. **AGENTS.md updated** -- Lines 93 and 171 reflect new body lifecycle policy
10. **ADR documented** -- `.archgate/adrs/ARCH-006-email-reference-storage.md` reflects all revised decisions

---

## ADR Reference

**Full ADR saved to:** `.archgate/adrs/ARCH-006-email-reference-storage.md`

### ADR Summary

- **Decision:** Reference-first email storage with inverted body lifecycle and thread-level stale tracking
- **Drivers:** Storage cost, processing correctness (CAS), user control
- **Alternatives considered:** Separate body table (rejected: over-engineered), compress in-place (rejected: doesn't solve process-once), email-level flag (rejected: thread-level is more efficient for batch queries)
- **Why chosen:** Minimal schema change, self-healing on failure, atomic CAS for concurrency, clean batch reprocessing via thread query
- **Consequences:** Body unavailable after cleanup in reference-only mode; two-phase lifecycle adds complexity; frontend must handle null body
- **Follow-ups:** `email_processing_log` table deferred to v2; Option B (separate body table) remains viable upgrade path

---

## Race Condition Documentation

Concurrent emails in the same thread are handled by the atomic CAS:

```sql
UPDATE threads SET markdown_stale = false WHERE id = $1 AND markdown_stale = true
```

- **Winner** (1 row updated): Proceeds with body cleanup. The winner's markdown update incorporates the most recent email context because the summarizer loads existing markdown + new email + coherence samples.
- **Loser** (0 rows updated): Skips body cleanup. The loser's email body remains intact until the next `markdown_stale = true` cycle (set when the next email arrives for the thread).
- **Stale re-trigger:** When a new email arrives for a thread, `markdown_stale` is set back to `true`, ensuring the new content is incorporated in the next pipeline run.

---

## Open Questions (Deferred)

See `.omc/plans/open-questions.md` for tracked items.
