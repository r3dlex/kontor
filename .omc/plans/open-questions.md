# Open Questions

## Email Reference Storage - 2026-04-06 (Revised)

### Carried Forward
- [ ] Should there be a "re-fetch body" button that calls Himalaya to retrieve the body on demand for reference-only emails? -- Could mitigate the downside of not storing bodies
- [ ] When `copy_emails` is toggled from false to true on an existing mailbox, should previously imported reference-only emails be backfilled? -- Backfilling requires re-reading from Himalaya and could be expensive
- [ ] Should `raw_headers` follow the same copy_emails logic as body, or should headers always be stored (they are small)? -- The plan currently treats them identically but headers are much smaller than bodies

### Resolved by Revision
- [x] ~~Should the frontend display a warning when viewing an email with `body: null`?~~ -- YES, Step 6 now includes null body handling with "Body not stored" message
- [x] ~~Is there a need for a batch reprocessing command for emails that failed markdown processing?~~ -- YES, the `MarkdownBackfillWorker` (Oban, 5-minute interval) handles this automatically
- [x] ~~Should the `markdown_processed` flag be resettable per-email or per-thread to force re-summarization?~~ -- RESOLVED: Flag moved to thread level (`markdown_stale`). Setting `markdown_stale = true` on a thread triggers reprocessing on the next backfill worker run

### New from Architect/Critic Review
- [ ] Should the `MarkdownBackfillWorker` have a configurable batch size and interval, or are the defaults (50 threads, 5 minutes) sufficient? -- Depends on expected email volume
- [ ] Should there be an admin endpoint to manually trigger the backfill worker for a specific tenant or thread? -- Useful for debugging but not essential for v1
- [ ] `email_processing_log` table deferred to v2 -- when should this be revisited? -- `markdown_stale` + `processed_at` provides minimal audit trail for v1, but detailed error tracking may be needed sooner if pipeline failures are common
- [ ] Should the CAS loser's email body be cleaned up eventually (it retains body until the next `markdown_stale = true` cycle)? -- Minor storage concern; the next email arrival resets the cycle

## Folder Organization System - 2026-04-07

- [ ] Should the nightly worker run time (23:00 UTC) be configurable per mailbox or tenant, or is a single global cron sufficient? — Users in far-off timezones may prefer a different local end-of-day time
- [ ] Should there be a way for the user to preview pending folder suggestions before the nightly run executes them? — Deferred to v2 per ADR but may surface as a user request early
- [ ] The `available_folders` list is fetched from Himalaya inside `run_one_tier2` only when the skill is `folder_organizer` — should this result be cached in ETS for the duration of the pipeline run to avoid repeated MCP calls for multi-email batches? — Low risk for now (single daily batch), but worth revisiting at scale
- [ ] Should `folder_bootstrap_count` be reset if a mailbox is re-imported from scratch (e.g. `ecto.reset` or a deliberate re-import)? — Currently no reset path exists; if the counter stays high after a re-import, the 50-email guard is bypassed

## Folder Organization Upgrade - 2026-04-08 (Revised)

### Resolved by Architect/Critic Review
- [x] ~~**Correction detection mechanism** — Step 8 proposes detecting user folder moves via IMAP polling diff~~ -- RESOLVED: `HimalayaClient` has no `get_email_folder` read-path. Corrections now come from a frontend API endpoint (`POST /api/v1/mailboxes/:id/folder_corrections`). Worker renamed to `SenderRulePromotionWorker`.
- [x] ~~**Token budget for unified classifier** — unified classifier receives full email body~~ -- RESOLVED: Unified classifier approach (Option B) invalidated. Tier 1 remains headers-only. No token budget increase for classifier.
- [x] ~~**Rollback strategy** — feature flag for unified vs old pipeline~~ -- RESOLVED: Rollback plan uses `active: false` in skill frontmatter + SkillLoader check. No runtime feature flag needed; skill file changes take effect immediately.

### Carried Forward
- [ ] **IMAP label support per provider** — Gmail supports labels natively; Microsoft uses categories. The `FolderOrganizerWorker` label-application logic needs provider-specific branching. How does `HimalayaClient` currently abstract this? Does it expose label/category APIs? — Still relevant for Phase 1; labels are persisted in DB but IMAP-side label application is provider-dependent
- [ ] **Priority score weight tuning** — The spec defines weights (sender relationship = very high, direct addressing = high, etc.) but not numeric coefficients. The current scorer uses `urgency*0.35 + action*0.30 + authority*0.20 + momentum*0.15`. Should the Tier 1 headers-only prompt use explicit numeric weights, or leave it to LLM judgment with qualitative guidance? — Now more constrained since Tier 1 only has header signals
- [ ] **Folder model transition** — The spec mandates action-based as the primary model, but existing mailboxes may have `folder_model: "structural_category"`. Should existing mailboxes be migrated to action-based, or should both models remain supported? The `mailbox.folder_model_locked_at` guard complicates forced migration.

### New from Revised Plan
- [ ] **Phase 2 evaluation criteria** — After 30 days of production data, what specific metrics determine whether full Tier 1/2 unification (Option B) should proceed? Suggested: compare average token cost per email, `context_depth` distribution, and classification accuracy between headers-only and full-body emails.
- [ ] **Labeler skill invocation scope** — Should the classifier always include "labeler" in `tier2_skills`, or only for certain email categories? Labeling every email may be unnecessary for spam/automated notifications with `context_depth: "none"`.
- [ ] **Frontend correction UX** — The new `POST /api/v1/mailboxes/:id/folder_corrections` endpoint requires the frontend to know the `from_folder` when a user moves an email. Does the current frontend track which folder an email is displayed in, or does this need to be added?

## Ingestion Behaviour Changes (Revised) - 2026-04-07

- [ ] Thread completeness uses `Task.start` (fire-and-forget) so the pipeline may summarise a thread before all siblings are in the DB — is an incomplete first-pass summary acceptable, relying on MarkdownBackfillWorker to correct it on the next 5-minute cycle? -- Accepted as a trade-off to avoid blocking the GenServer, but worth confirming with product
- [ ] The sibling fetch only covers the INBOX folder — should Sent and Archive folders also be searched for thread completeness? -- Deferred; requires either multiple `list_emails` calls or a new `list_thread_emails` MCP endpoint from Himalaya
- [ ] Should `HimalayaClient.list_emails` log the sort-fallback warning at `:warning` level or `:info`? -- Currently `:warning`; if Himalaya consistently rejects the param it will produce noise; consider `:info` after confirming Himalaya behaviour in staging
- [ ] The `active` field migration (`20260407000005`) sets `default: true` at the DB level — should existing inactive mailboxes (if any exist in production) be explicitly audited before migration? -- Migration is safe for new installs; production operators should verify no mailboxes need `active: false` before running
