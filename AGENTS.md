# Kontor Project Specification

## Project Overview

**Kontor** is an AI-driven email application that unifies multiple mailboxes into a single prioritized, task-oriented interface. The AI agent classifies, scores, summarizes, and organizes all email activity. Every AI behavior is encoded as a self-evolving skill. A persistent chat interface provides contextual interaction across every view.

Deployment: Single-tenant. Data model: Multi-tenant (tenant_id on every table and operation) for future migration.

## Architecture

### Runtime Stack

| Component | Technology | Role |
|-----------|-----------|------|
| Backend | Elixir / Phoenix | API, email processing, AI orchestration |
| Frontend | Vue 3 SPA | User interface (Vite, Pinia, Vue Router, TipTap) |
| Desktop | Tauri | Native window wrapper |
| Database | PostgreSQL + pgvector | Relational data, vector search |
| Email Transport | Himalaya MCP | IMAP, JMAP, SMTP protocol handling |
| Embeddings | Bumblebee/Nx + all-MiniLM-L6-v2 | Text embeddings (~80MB, 384 dimensions) |
| LLM Provider | MiniMax | API-only, Strategy C with aggressive caching |
| Calendar (Google) | Google Calendar MCP | Read/create events |
| Calendar (Microsoft) | Graph API | Direct Elixir client |
| Task Sync | Asana MCP (roychri/mcp-server-asana) | Task synchronization |
| Automation | n8n | Bidirectional webhooks |
| Contact Graph | Vis.js Network | Relationship visualization |
| MCP Framework | anubis-mcp | Elixir-native MCP server/client |

### Directory Layout

```
lib/kontor/
├── accounts/          # User and mailbox management
├── mail/              # Email receive, send, folder ops
├── ai/                # Skill execution, pipeline, sandbox
├── mcp/               # MCP clients (Himalaya, Asana, Google)
├── calendar/          # Google + Microsoft event management
├── tasks/             # Task creation, Asana sync
├── contacts/          # Contact profiles, relationship graph
├── chat/              # Persistent chat sessions
├── auth/              # OAuth token management
├── documents/         # Document management
├── automations/       # n8n webhook automation
├── search/            # Full-text and semantic search
├── application.ex
├── cache.ex
├── repo.ex
└── vault.ex

lib/kontor_web/
├── router.ex          # Route definitions
├── controllers/       # REST handlers
├── channels/          # WebSocket channels (chat, notifications, tasks, contacts)
└── plugs/             # Plug middleware (authenticate_tenant)

priv/skills/shared/    # Default skill markdown files (classifier, scorer, summarizer, etc.)
priv/skills/{mailbox}/ # Mailbox-specific skill overrides
priv/profiles/         # Style profile markdown files
priv/repo/migrations/  # Ecto migrations

frontend/              # Vue 3 SPA
├── src/
│   ├── components/
│   ├── views/
│   ├── stores/        # Pinia stores
│   ├── layouts/
│   ├── router/
│   ├── api/
│   └── main.js
└── vite.config.js

src-tauri/             # Tauri desktop wrapper
```

### Key Design Decisions

#### 1. Email Transport (Himalaya MCP)
- **Himalaya owns all email protocol**: IMAP, JMAP, SMTP, Notmuch
- **Elixir never touches email protocols** — communicates exclusively via anubis-mcp
- **Exceptions**: Scheduled email sending (OTP process), CalDav/CardDav (Elixir)
- **Provider Integration**:
  - **Google (Gmail)**: OAuth 2.0 → Himalaya (IMAP/SMTP) → Google Calendar MCP, CardDav (Elixir)
  - **Microsoft (O365)**: OAuth 2.0 via DavMail → Himalaya (IMAP/SMTP via DavMail) → Graph API (Elixir)
- **Token Management**: PostgreSQL (encrypted via cloak_ecto), eager refresh at 80% lifetime

#### 2. Skill System
- **Format**: YAML frontmatter + markdown body
- **Storage**: PostgreSQL source of truth (skills, skill_versions tables); filesystem is runtime cache
- **Execution**: LLM-interpreted prompt templates, NOT compiled code
- **Namespacing**:
  - `priv/skills/shared/` — apply across all mailboxes
  - `priv/skills/{mailbox}/` — mailbox-specific overrides
- **Versioning**: LLM and humans can create/modify skills; version tracking enabled
- **Webhook Integration**: Optional n8n webhook in frontmatter for async notifications

#### 3. Two-Tier Pipeline
- **Tier 1 (Classifier)**: Input = subject + sender + recipients only (minimal tokens) → Output = category, urgency, list of Tier 2 skill IDs
- **Tier 2 (Specialized Skills)**: Only classifier-selected skills loaded → receive prescribed context depth

#### 4. Thread Markdown System
- **Per-thread document**: Persistent markdown accumulation
- **Lossy compression**: On new email, load existing markdown + new email + 1-5 random prior emails (coherence sampling) → LLM updates markdown
- **Body lifecycle**: Email bodies inserted at import, conditionally discarded after AI processing (per mailbox.copy_emails setting); markdown is the primary working document
- **Embeddings**: pgvector for semantic search across threads

#### 5. AI Sandbox
- **Locus**: Elixir backend is the sandbox
- **LLM isolation**: LLM never accesses network directly
- **Validation**: Allowlist GenServer (Sandbox.execute/4) validates all LLM-proposed actions from both pipeline writes and chat actions
- **Atom exhaustion protection**: Unknown LLM keys are dropped, never converted to atoms via String.to_atom/1
- **Frontend integration**: Vue declares available_actions per view; backend validates against allowlist
- **Permitted Actions**: Read emails (tenant-scoped), write/update thread markdowns, update scores, draft replies, create/update calendar entries, manage skills (tenant-scoped), create/update tasks, manage folder organization

### Memory Budget (Target 1GB Total)
- Phoenix + BEAM: ~200MB
- PostgreSQL: ~300MB
- Himalaya processes: ~50MB
- Bumblebee model: ~80MB
- ETS caches/GenServers/workers: ~150MB
- Headroom: ~220MB

## Skill System Detail

### Skill Format (YAML Frontmatter + Markdown Body)

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
[Markdown prompt template for LLM]
```

### Default Skill Inventory (v1)

1. **Classifier (Tier 1)** — Routes emails to Tier 2 skills based on subject, sender, recipients
2. **Scorer (Tier 2)** — Multi-dimensional scoring (urgency, action required, sender authority, thread momentum)
3. **Thread Summarizer (Tier 2)** — Lossy markdown accumulation with coherence sampling
4. **Task Extractor (Tier 2)** — Identifies actionable items, auto-confirms high-confidence
5. **Reply Drafter (Tier 2)** — Generates contextual draft responses
6. **Meeting Setup (Tier 2)** — Extracts scheduling intent from emails
7. **Calendar Reminder (Tier 2)** — Detects deadlines and calendar events
8. **Briefing Generator (Tier 2)** — Back Office daily briefing aggregation
9. **Folder Organizer (Tier 2)** — Folder routing based on content
10. **Contact Organizer (Tier 2)** — Contact profiles and relationship edge extraction

## Email Processing Pipeline

### Tier 1: Classifier
- **Input**: subject + sender + recipients only
- **Output**: category, urgency, list of Tier 2 skill IDs, context depth

### Tier 2: Specialized Skills
- **Execution**: Only classifier-selected skills loaded
- **Context**: Prescribed depth (full body, thread history, attachments)

## Thread Markdown System

Each thread gets a persistent markdown document. On new email arrival:
1. Load existing thread markdown
2. Load new email
3. Load 1-5 random prior thread emails (coherence sampling)
4. LLM updates markdown
5. Email bodies conditionally discarded after AI processing (retained when mailbox.copy_emails = true)
6. Markdown is lossy working document for AI-driven UX

## Contact Intelligence

- **One record per unique email address** → contact record
- **Contact Organizer skill**: Builds profile markdown
- **Lossy accumulation**: Same coherence sampling pattern as threads
- **Metrics**: contact_mailbox_context tracks per-mailbox interaction metrics
- **Visualization**: Vis.js Network for relationship graph

## Scoring System

### Four Dimensions
1. **Urgency** — Deadlines, temporal signals
2. **Action Required** — Task extraction confidence
3. **Sender Authority** — Contact relationship and role
4. **Thread Momentum** — Conversation velocity and engagement

### Implementation
- **Composite blend**: Weighted average
- **Weight storage**: User preferences markdown
- **Caching**: ETS for repeat patterns (newsletters, automated notifications)

## Task System

### Types
- Reply
- Meeting Setup
- Calendar Reminder
- Custom

### State Machine
`created` → `confirmed` → `in_progress` → `done` | `dismissed` | `expired`

### Auto-Confirmation
- **\>0.85 confidence**: Auto-confirmed + Asana sync
- **0.5-0.85**: Suggested (user review required)
- **<0.5**: Logged only

### Settings
- **Default age cutoff**: 3 months
- **Asana sync**: One-way push with pull reconciliation
- **Project per tenant**: One Asana project per tenant

## Data Model

All tables include `tenant_id` for multi-tenant support:

- **users** — Tenant members, OAuth credentials
- **mailboxes** — Email accounts (Gmail, O365, IMAP)
- **credentials** — Encrypted API tokens
- **emails** — Raw email documents with headers, body, attachments
- **threads** — Email thread grouping
- **thread_embeddings** — pgvector embeddings for semantic search
- **thread_relationships** (v2) — Cross-thread similarity
- **thread_markdowns** — Accumulated skill-generated summaries
- **tasks** — Extracted actionable items
- **skills** — Skill definitions and metadata
- **skill_versions** — Version history for audit
- **calendar_events** — Unified Google + Microsoft events
- **chat_sessions** — Persistent conversation contexts
- **chat_messages** — Chat history
- **style_profiles** — User writing style templates
- **scheduled_sends** — Deferred email sends
- **contacts** — Contact directory
- **contact_mailbox_context** — Per-mailbox interaction metrics
- **contact_relationships** — Relationship edges
- **contact_embeddings** — Contact profile embeddings
- **org_charts** (v2) — Organization hierarchy

## Supervision Tree

```
Kontor.Application
├── Kontor.Repo
├── Kontor.Vault (encrypted key storage)
├── Phoenix.PubSub
├── KontorWeb.Endpoint
├── Kontor.Cache (ETS tables for performance)
├── {Oban, ...} (job queue for background workers)
├── Kontor.MCP.Supervisor
│   ├── HimalayaClient per mailbox
│   ├── AsanaClient
│   ├── GoogleCalendarClient
│   └── OutboundServer (Calendar, Documents, Configuration, Skills, Automations)
├── Kontor.Mail.Supervisor
│   ├── Poller per mailbox (IMAP idle, periodic fetch)
│   ├── Importer (processes new emails)
│   └── ScheduledSender
├── Kontor.AI.Supervisor
│   ├── Sandbox (allowlist validator)
│   ├── SkillLoader (filesystem sync, hot reload)
│   ├── Pipeline (Tier 1 classifier, Tier 2 specialist execution)
│   └── Embeddings (Bumblebee model server)
├── Kontor.Calendar.Supervisor
│   ├── GoogleSync (periodic read from MCP)
│   ├── MicrosoftSync (periodic Graph API read)
│   └── BriefingWorker (daily aggregation)
├── Kontor.Tasks.Supervisor
│   ├── AsanaSyncWorker (bidirectional)
│   └── ExpirationWorker (cleanup old tasks)
├── Kontor.Contacts.Supervisor
│   ├── OrganizationWorker (org chart sync)
│   └── RelationshipGraphWorker (Vis.js network data)
└── Kontor.Auth.TokenRefresher (timer-based OAuth refresh)
```

## API Contract

### WebSocket Channels
- `chat:{user_id}` — Real-time messaging
- `notifications:{user_id}` — Alerts (new email, task, etc.)
- `tasks:{user_id}` — Task updates
- `contacts:{user_id}` — Contact graph updates

### REST Endpoints

#### Authentication
- `POST /api/v1/auth/google` — Google OAuth callback
- `POST /api/v1/auth/microsoft` — Microsoft OAuth callback

#### Email & Threads
- `GET /api/v1/mailboxes` — List connected mailboxes
- `GET /api/v1/emails/:id` — Get single email
- `GET /api/v1/threads/:id` — Get thread with markdown
- `PATCH /api/v1/threads/:id` — Update thread markdown, scores, labels

#### Tasks
- `GET /api/v1/tasks` — List user tasks
- `POST /api/v1/tasks` — Create task
- `PATCH /api/v1/tasks/:id` — Update task state
- `DELETE /api/v1/tasks/:id` — Delete task

#### Calendar
- `GET /api/v1/calendar/today` — Today's events
- `GET /api/v1/calendar/briefing/:id` — Briefing for date
- `POST /api/v1/calendar/events` — Create event
- `PATCH /api/v1/calendar/events/:id` — Update event

#### Back Office
- `GET /api/v1/backoffice` — Dashboard data

#### Skills
- `GET /api/v1/skills` — List skills
- `GET /api/v1/skills/:id` — Get skill content
- `POST /api/v1/skills/:id/execute` — Trigger skill manually
- `PUT /api/v1/skills/:id` — Update skill (LLM or human)

#### Profiles
- `GET /api/v1/profiles` — List style profiles
- `POST /api/v1/profiles` — Create profile
- `PATCH /api/v1/profiles/:id` — Update profile

#### Drafts & Config
- `GET /api/v1/drafts` — List draft replies
- `POST /api/v1/drafts` — Save draft
- `GET /api/v1/config` — User preferences
- `PATCH /api/v1/config` — Update preferences

#### Contacts
- `GET /api/v1/contacts` — List contacts
- `GET /api/v1/contacts/:id` — Get contact with profile
- `GET /api/v1/org-charts` — Organization relationships (Vis.js data)

## Development Setup

### Prerequisites
- Elixir 1.17+, Erlang/OTP 25+
- Node.js 18+
- PostgreSQL 15+
- Tauri CLI
- n8n (optional, for automation testing)

### Backend Setup
```bash
# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.create
mix ecto.migrate

# Start Phoenix server
mix phx.server
```
Server runs on `http://localhost:4737`

### Frontend Setup
```bash
cd frontend
npm install
npm run dev
```
Frontend runs on `http://localhost:5173`

### Desktop Build
```bash
cd src-tauri
npm install
npm run tauri dev
```

## v1 Scope

Core email unification, basic AI classification and scoring, thread markdown generation, reply drafting, task extraction, calendar integration (Google + Microsoft), skill system, multi-mailbox support, persistent chat, contact profiles, Asana sync, n8n integration.

## v2 Scope

Skill evolution (LLM retraining loop), cross-thread relationship discovery, skill editor UI, automatic style extraction, true multi-tenant (deployment, auth), remote MCP server authentication, contact organization graph, advanced search with embeddings.
