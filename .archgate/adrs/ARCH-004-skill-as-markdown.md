---
id: ARCH-004
title: Skills are markdown prompt templates, not compiled code
domain: skill-system
rules: true
files: ["priv/skills/**/*.md"]
---

# ARCH-004: Skills Are Markdown Prompt Templates, Not Compiled Code

## Status

Accepted

## Context

The Kontor skill system allows the LLM and human operators to create, modify, and version skills that control AI behavior. A skill encodes a prompt template that the LLM interprets at runtime. Skills must remain in a format that:
1. Is human-readable and auditable
2. Can be safely stored in PostgreSQL and served at runtime
3. Cannot be exploited to execute arbitrary code on the server
4. Can be version-controlled and diffed meaningfully

If skills contained executable code (Elixir, TypeScript, Python), they would become an arbitrary code execution vector. Any skill update — whether from the LLM or a human — could introduce malicious code that runs with server privileges.

## Decision

**Skills are YAML frontmatter + markdown body files only. They must not contain executable code blocks.**

Specifically:
- Every `.md` file in `priv/skills/` must have valid YAML frontmatter
- Required frontmatter fields: `name`, `namespace`, `version`, `author`
- Skills may contain markdown code blocks for _illustrative_ purposes (showing format examples), but these are never executed
- Elixir (`.ex`, `.exs`), TypeScript (`.ts`), and Python (`.py`) files must not be placed in `priv/skills/`

## Skill Frontmatter Schema

```yaml
---
name: <string>           # Unique skill identifier within namespace
namespace: <string>      # "shared" or mailbox identifier
version: <integer>       # Monotonically increasing version number
author: <string>         # "llm" or GitHub username
locked: <boolean>        # Optional: prevent LLM modification
trigger:                 # Optional: execution trigger conditions
  tier: <1|2>
  conditions: <map>
input_schema: <list>     # Optional: expected input context fields
output_schema: <list>    # Optional: expected output fields
webhook: <url>           # Optional: n8n notification webhook
priority: <integer>      # Optional: execution priority (lower = higher)
---
```

## Consequences

**Positive:**
- Skills cannot be weaponized as code execution vectors
- Any operator (including the LLM) can safely create/modify skills without code review
- Skills are portable: they can be exported, shared, and imported without security concerns
- Diffs are human-readable markdown

**Negative:**
- Complex conditional logic must be encoded as natural language instructions to the LLM
- Skills cannot perform pre/post processing without a companion Elixir module

## Enforcement

The archgate rule validates YAML frontmatter presence and required field completeness on all `.md` files in `priv/skills/`.
