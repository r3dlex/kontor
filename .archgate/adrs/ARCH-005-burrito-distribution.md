---
id: ARCH-005
title: Zero-install distribution via Burrito
domain: distribution
rules: true
files: ["mix.exs"]
---

# ARCH-005: Zero-Install Distribution via Burrito

## Status

Accepted

## Context

Kontor targets end-users who should not need to install Elixir, Erlang/OTP, or any runtime dependencies to run the application. Traditional Elixir releases require the target machine to have a compatible Erlang runtime installed, which creates a significant barrier to adoption.

Burrito is an Elixir library that wraps a Mix release into a self-contained binary that bundles the Erlang runtime. The result is a single executable per platform that runs without any pre-installed dependencies.

## Decision

**The Kontor release must use Burrito for cross-platform zero-install binary distribution.**

Specifically:
- `mix.exs` must list `:burrito` as a dependency
- The `releases/0` function in `mix.exs` must configure Burrito targets:
  - `macos_arm` — macOS ARM64 (Apple Silicon)
  - `macos_x86` — macOS x86_64 (Intel)
  - `linux_x86` — Linux x86_64
- Release steps must include `&Burrito.wrap/1`
- CI must produce one artifact per target platform

## Release Configuration

The releases configuration follows the Burrito format:

```elixir
defp releases do
  [
    kontor: [
      steps: [:assemble, &Burrito.wrap/1],
      burrito: [
        targets: [
          macos_arm: [os: :darwin, cpu: :aarch64],
          macos_x86: [os: :darwin, cpu: :x86_64],
          linux_x86: [os: :linux, cpu: :x86_64]
        ]
      ]
    ]
  ]
end
```

## Consequences

**Positive:**
- End-users install Kontor by downloading a single binary — no Elixir/Erlang required
- Cross-platform distribution from a single CI pipeline
- Binary is reproducible and version-pinned

**Negative:**
- Binary size is larger (~50-100MB) due to bundled runtime
- Burrito wrapping adds time to the release build
- Platform-specific builds must be produced on the correct runner OS (macOS binaries on macOS runners)

## Enforcement

The archgate rule verifies that `mix.exs` contains both "burrito" in the `deps` section and in the `releases` configuration function.
