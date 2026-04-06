<picture>
  <source media="(prefers-color-scheme: dark)" srcset="frontend/public/brand/kontor-wordmark-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="frontend/public/brand/kontor-wordmark-light.svg">
  <img alt="Kontor" src="frontend/public/brand/kontor-wordmark-light.svg" height="56">
</picture>

**AI-driven email, unified.**

---

## Overview

Kontor is a single-tenant, AI-driven email application that unifies multiple mailboxes into one prioritized, task-oriented interface. Every AI behavior — classification, scoring, summarization — is encoded as a self-evolving skill. A persistent chat assistant provides contextual interaction across every view.

## Features

- **Multi-mailbox unification** — aggregate inboxes with AI-driven priority scoring across all accounts
- **AI skill system** — self-evolving classifiers, scorers, and summarizers with version history and an in-app editor UI
- **Persistent chat assistant** — context-aware conversational AI available across all views
- **Calendar briefings** — daily back-office view with Google Calendar and Microsoft Graph integration
- **Contact relationship graph** — interactive vis.js network visualization of contact relationships
- **Semantic search** — pgvector-powered similarity search across all email content
- **Asana task sync** — bidirectional task synchronization via MCP
- **MCP server/client** — extensible Model Context Protocol integration via anubis-mcp

## Architecture

Kontor follows a Phoenix/Elixir backend with a Vue 3 SPA frontend, connected over REST and Phoenix Channels (WebSocket). AI processing runs in-process via Bumblebee/Nx for embeddings and MiniMax for LLM inference.

```
lib/kontor/
├── accounts/      # User and mailbox management
├── mail/          # Email receive, send, folder ops
├── ai/            # Skill execution, pipeline, sandbox
├── mcp/           # MCP clients (Himalaya, Asana, Google)
├── calendar/      # Google + Microsoft event management
├── tasks/         # Task creation, Asana sync
├── contacts/      # Contact profiles, relationship graph
├── chat/          # Persistent chat sessions
└── auth/          # OAuth token management

frontend/src/
├── views/         # Page-level Vue components
├── stores/        # Pinia state management
└── components/    # Shared UI components
```

## Tech Stack

| Layer | Technology | Role |
|---|---|---|
| Backend | Elixir / Phoenix | API, email processing, AI orchestration |
| Frontend | Vue 3 + Pinia | SPA (Vite, Vue Router, TipTap) |
| Desktop | Tauri | Native window wrapper |
| Database | PostgreSQL + pgvector | Relational data and vector search |
| Embeddings | Bumblebee / Nx | Local text embeddings (all-MiniLM-L6-v2) |
| LLM | MiniMax | API inference with aggressive caching |
| Real-time | Phoenix Channels | WebSocket (chat, notifications, tasks) |

## Getting Started

### Prerequisites

- Elixir 1.16+ and Erlang/OTP 26+
- Node.js 20+
- PostgreSQL 15+ with the pgvector extension

### Backend

```bash
mix deps.get
mix ecto.setup
mix phx.server
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

The Phoenix API runs on `http://localhost:4000`. The Vite dev server runs on `http://localhost:5173` and proxies API requests automatically.

## Running Tests

**Backend**

```bash
mix test
```

**Frontend**

```bash
npm test
# With coverage
npm run test:coverage
```

**End-to-end**

```bash
npx playwright test
```

## License

Proprietary. All rights reserved.
