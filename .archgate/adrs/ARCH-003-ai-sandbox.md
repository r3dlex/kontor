---
id: ARCH-003
title: LLM actions must pass through AI Sandbox
domain: ai
rules: true
files: ["lib/kontor/ai/**/*.ex"]
---

# ARCH-003: LLM Actions Must Pass Through AI Sandbox

## Status

Accepted

## Context

Kontor uses an LLM (MiniMax) to classify emails, extract tasks, draft replies, and propose actions. A key security property of the system is that the LLM never has direct network access or the ability to take arbitrary actions. All LLM-proposed actions must be validated against an allowlist before execution.

Without this guardrail, a prompt injection attack or a misbehaving model could cause the LLM to exfiltrate data, send unauthorized emails, or modify records it should not touch.

## Decision

**All LLM-proposed actions must pass through `Kontor.AI.Sandbox` before execution.**

The Sandbox is an allowlist-based GenServer (`lib/kontor/ai/sandbox.ex`) that:
1. Receives a proposed action from the LLM pipeline
2. Validates the action against a per-tenant allowlist
3. Returns `:allow` or `{:deny, reason}` before any side effect is performed

Specifically:
- `lib/kontor/ai/pipeline.ex` must reference `Sandbox` or `AI.Sandbox` — all pipeline execution flows through sandbox validation
- Direct `Req.get/2` or `Req.post/2` calls in AI modules are violations, except in:
  - `lib/kontor/ai/minimax_client.ex` — the designated LLM API client
  - `lib/kontor/ai/embeddings.ex` — the designated embeddings model server

## Rationale

The LLM is an untrusted executor. It operates on user data and external content (emails) that may contain adversarial prompt injections. The Sandbox provides a mandatory checkpoint that cannot be bypassed by the LLM's output, regardless of what the prompt instructs.

## Consequences

**Positive:**
- Prompt injection attacks cannot cause unauthorized actions
- All LLM-proposed actions are auditable (sandbox logs every decision)
- The allowlist is tenant-configurable, enabling fine-grained permission control

**Negative:**
- Every new action type requires an explicit allowlist entry
- Sandbox is a bottleneck in the AI pipeline (mitigated by GenServer call batching)

## Permitted Exceptions

- `lib/kontor/ai/minimax_client.ex` — makes outbound HTTP calls to the MiniMax API
- `lib/kontor/ai/embeddings.ex` — serves embeddings via Bumblebee/Nx (in-process, no network)
