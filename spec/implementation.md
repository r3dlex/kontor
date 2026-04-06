# Kontor: Implementation Specification v1.1

## Overview
Kontor is an AI-driven email application that unifies multiple mailboxes into a single prioritized task-oriented interface. The AI agent classifies, scores, summarizes, and organizes all email activity. Every AI behavior is encoded as a self-evolving skill. A persistent chat interface provides contextual interaction across every view.

Single-tenant deployment. Multi-tenant data model (tenant_id on every table and operation) for future migration.

## Architecture

### Runtime Stack
- Backend: Elixir / Phoenix
- Frontend: Vue 3 SPA
- Desktop: Tauri
- Database: PostgreSQL with pgvector
- Email Transport: Himalaya via MCP (anubis-mcp)
- Embeddings: Bumblebee/Nx with all-MiniLM-L6-v2 (~80MB, 384 dimensions)
- LLM Provider: MiniMax (API-only, Strategy C with aggressive caching)
- Calendar (Google): External Google Calendar MCP server
- Calendar (Microsoft): Direct Graph API client in Elixir
- Task Sync: Asana MCP (roychri/mcp-server-asana)
- Automation: n8n via webhooks (bidirectional)
- Contact Graph: Vis.js Network
- MCP Framework: anubis-mcp (Elixir-native)

### Memory Budget (Target 1GB total)
- Phoenix + BEAM: ~200MB
- PostgreSQL: ~300MB
- Himalaya processes: ~50MB
- Bumblebee model: ~80MB
- ETS caches/GenServers/workers: ~150MB
- Headroom: ~220MB

## Email Transport Layer
Decision: Himalaya as Single Mail Transport. Himalaya owns all email protocol handling: IMAP, JMAP, SMTP, Notmuch. The Elixir backend communicates with Himalaya exclusively through MCP via anubis-mcp. No email protocol code exists in Elixir.

Exceptions handled natively in Elixir: Scheduled email sending (OTP process scheduling), CalDav/CardDav.

Provider Integration:
- Google (Gmail): OAuth 2.0 SSO | Himalaya (IMAP/SMTP) | Google Calendar MCP | CardDav (Elixir)
- Microsoft (O365): OAuth 2.0 SSO via DavMail | Himalaya (IMAP/SMTP via DavMail) | Graph API (Elixir) | Graph API (Elixir)

Token Management:
- Storage: PostgreSQL credentials table, encrypted at rest using cloak_ecto
- Refresh strategy: Eager. Timer-based refresh at 80% of token lifetime elapsed

## MCP Topology

Inbound MCP Connections (Kontor consumes):
1. Himalaya MCP — email read, send, folder management
2. Asana MCP — task synchronization (roychri/mcp-server-asana)
3. Google Calendar MCP — Google calendar event access

Outbound MCP Server (Kontor exposes) — One server, five namespaces, localhost, auth stubs:
- Calendar: Read/create/update/delete events, get briefings (unified Google+Microsoft)
- Documents: Push transcripts, meeting minutes, notes, reports
- Configuration: Theme, polling frequency, font, read/write mode
- Skills: List skills, read content, trigger execution
- Automations: Trigger skills externally, register webhooks, query execution history

n8n Integration: Skills have optional webhook field in YAML frontmatter. Result payload POST'd to n8n when skill executes. n8n can trigger skills through Automations namespace.

## AI Sandbox
Elixir backend is the sandbox. LLM never accesses network directly. Allowlist GenServer validates every LLM-proposed action. Vue frontend declares available_actions per view. Backend validates against allowlist.

Permitted actions: Read emails (tenant-scoped), write/update thread markdowns, update scores, draft replies, create/update calendar entries, manage skills (tenant-scoped), create/update tasks, manage folder organization.

## Skill System

Skill Format (YAML frontmatter + markdown body):
```yaml
---
name: reply_drafter
namespace: shared
version: 7
author: llm
locked: false
trigger:
  tier: 2
  conditions:
    task_type: reply
    min_score_action: 0.6
input_schema:
  - thread_markdown
  - source_email
  - style_profile
output_schema:
  - draft_content
  - confidence
webhook: https://n8n.local/webhook/reply-drafted
priority: 10
---
```

Storage: PostgreSQL is source of truth (skills + skill_versions tables). Filesystem markdown files are runtime cache, synced on boot and on change. LLM reads from filesystem only.

Namespacing:
- skills/shared/ — apply across all mailboxes
- skills/{mailbox}/ — mailbox-specific overrides

Default Skill Inventory (v1):
1. Classifier (Tier 1) — Routes emails to Tier 2 skills
2. Scorer (Tier 2) — Multi-dimensional scoring
3. Thread Summarizer (Tier 2) — Markdown generation with coherence sampling
4. Task Extractor (Tier 2) — Identifies actionable items
5. Reply Drafter (Tier 2) — Generates draft responses
6. Meeting Setup (Tier 2) — Extracts scheduling intent
7. Calendar Reminder (Tier 2) — Detects deadlines
8. Briefing Generator (Tier 2) — Back Office daily briefing
9. Folder Organizer (Tier 2) — Folder routing
10. Contact Organizer (Tier 2) — Contact profiles and relationship edges

## Email Processing Pipeline

Tier 1 (Classifier): Input = subject + sender + recipients only. Output = category, urgency, list of Tier 2 skill IDs, context depth needed.

Tier 2 (Specialized Skills): Only classifier-selected skills loaded. Each receives prescribed context depth.

## Thread Markdown System
Each thread gets a persistent markdown document. On new email: load existing markdown + new email + 1-5 random prior thread emails (coherence sampling) → LLM updates markdown. Raw emails always preserved in PostgreSQL. Markdown is lossy working document.

## Contact Intelligence
Each unique email address → contact record. Contact Organizer skill builds profile markdown. Lossy accumulation with coherence sampling (same pattern as threads). contact_mailbox_context table tracks per-mailbox interaction metrics. Relationship graph: Vis.js Network.

## Scoring System
Four dimensions: Urgency, Action Required, Sender Authority, Thread Momentum. Composite weighted blend. Weights in user preferences markdown. ETS cache for repeat patterns (newsletters, automated notifications).

## Task System
Types: Reply, Meeting Setup, Calendar Reminder, Custom. State machine: created → confirmed → in_progress → done | dismissed | expired.
Auto-confirmation: >0.85 auto-confirmed + Asana sync; 0.5-0.85 = suggested; <0.5 = logged only.
Default age cutoff: 3 months.
Asana sync: One-way push with pull reconciliation. One project per tenant.

## Data Model (all tables include tenant_id)
Tables: users, mailboxes, credentials, emails, threads, thread_embeddings, thread_relationships(v2), tasks, skills, skill_versions, calendar_events, chat_sessions, chat_messages, style_profiles, scheduled_sends, contacts, contact_mailbox_context, contact_relationships, contact_embeddings, org_charts

## Supervision Tree
Kontor.Application
├── Kontor.Repo
├── Kontor.Vault
├── KontorWeb.Endpoint
├── Kontor.MCP.Supervisor (HimalayaClient per mailbox, AsanaClient, GoogleCalendarClient, OutboundServer)
├── Kontor.Mail.Supervisor (Poller per mailbox, Importer, ScheduledSender/Oban)
├── Kontor.AI.Supervisor (Sandbox, SkillLoader, Pipeline, Embeddings)
├── Kontor.Calendar.Supervisor (GoogleSync, MicrosoftSync, BriefingWorker)
├── Kontor.Tasks.Supervisor (AsanaSyncWorker, ExpirationWorker)
├── Kontor.Contacts.Supervisor (OrganizationWorker, RelationshipGraphWorker)
├── Kontor.Auth.TokenRefresher
└── Kontor.Cache

## API Contract
Channels: chat:{user_id}, notifications:{user_id}, tasks:{user_id}, contacts:{user_id}
REST: /api/v1/auth/google, /api/v1/auth/microsoft, /api/v1/mailboxes, /api/v1/emails/:id, /api/v1/threads/:id, /api/v1/tasks, /api/v1/calendar/today, /api/v1/calendar/briefing/:id, /api/v1/backoffice, /api/v1/skills, /api/v1/profiles, /api/v1/drafts, /api/v1/config, /api/v1/contacts, /api/v1/org-charts

## v1 Scope (all items listed in spec)
## v2 Scope (skill evolution, cross-thread relationships, skill editor UI, style extraction, multi-tenant, remote MCP auth)
