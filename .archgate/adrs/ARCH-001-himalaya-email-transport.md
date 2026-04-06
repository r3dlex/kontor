---
id: ARCH-001
title: Himalaya as sole email transport
domain: email
rules: true
files: ["lib/kontor/mail/**/*.ex", "lib/kontor/mcp/**/*.ex"]
---

# ARCH-001: Himalaya as Sole Email Transport

## Status

Accepted

## Context

Kontor must support multiple email providers (Gmail via IMAP/SMTP, Microsoft O365 via DavMail, and generic IMAP accounts). Implementing protocol-level email handling in Elixir would require maintaining low-level TCP, TLS, and protocol state machines for IMAP, SMTP, and JMAP. This creates significant complexity, security surface area, and maintenance burden.

Himalaya is a mature, battle-tested Rust CLI email client that handles all protocol concerns. The project uses anubis-mcp as an Elixir-native MCP framework to communicate with Himalaya over its MCP interface.

## Decision

**All email protocol code must go through Himalaya MCP.** The Elixir backend communicates with Himalaya exclusively via the anubis-mcp client. No direct IMAP, SMTP, or JMAP protocol code is permitted in the Elixir codebase, except in the designated `himalaya_client.ex` file which wraps the MCP communication.

Specifically:
- `lib/kontor/mail/` modules must not open raw TCP/SSL sockets for email protocols
- `lib/kontor/mcp/` modules must not contain IMAP CAPABILITY commands, SMTP EHLO handshakes, or JMAP method calls outside of the Himalaya MCP wrapper
- String literals `"IMAP"` and `"SMTP"` used as protocol markers (not documentation or error messages) are violations
- Erlang modules `:gen_tcp` and `:ssl` must not be imported or used in mail or MCP modules (except `himalaya_client.ex`)

## Consequences

**Positive:**
- Protocol complexity is entirely delegated to a purpose-built Rust tool
- Himalaya handles OAuth token injection, TLS negotiation, and provider quirks
- Elixir code remains at the application logic layer
- Security surface area for email protocol handling is minimized

**Negative:**
- Runtime dependency on the Himalaya binary being present
- MCP communication overhead per email operation
- Himalaya version upgrades require testing the MCP interface contract

## Exceptions

- `lib/kontor/mcp/himalaya_client.ex` — This is the designated integration point and may reference protocol terms in comments and error messages
- CalDav/CardDav remain as direct Elixir HTTP calls (not IMAP/SMTP/JMAP)
- Scheduled email sending via OTP processes delegates final delivery to Himalaya MCP
