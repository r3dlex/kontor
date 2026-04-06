---
id: ARCH-002
title: All queries scoped by tenant_id
domain: data-access
rules: true
files: ["lib/kontor/**/*.ex"]
---

# ARCH-002: All Database Queries Scoped by tenant_id

## Status

Accepted

## Context

Kontor is deployed as a single-tenant application today but uses a multi-tenant data model (every table has a `tenant_id` column) to enable future migration to true multi-tenant deployment. The primary risk in a multi-tenant data model is cross-tenant data leakage: a query that omits the `tenant_id` filter could expose one tenant's emails, tasks, or contacts to another tenant.

This risk exists even in single-tenant deployments because it indicates a code path that will silently become a security vulnerability when multi-tenant deployment is activated.

## Decision

**Every database query that retrieves multiple records or looks up a single record by a non-unique identifier must include `tenant_id` scoping.**

Specifically:
- `Repo.all(query)` calls must be preceded by a `where: [tenant_id: ...]` clause within 10 lines of code
- `Repo.get(schema, id)` calls are discouraged — use `Repo.get_by(schema, id: id, tenant_id: tenant_id)` instead
- `Repo.one(query)` calls follow the same rule as `Repo.all`
- Ecto query compositions using `from` must include a `where` clause filtering on `tenant_id`

## Rationale

The `tenant_id` must be present at the query construction site, not assumed to be applied by an upstream caller. Defense in depth requires each data access function to be independently correct.

## Consequences

**Positive:**
- Data isolation is enforced at every query site
- Code review can mechanically verify compliance
- Future multi-tenant activation will not require auditing all query sites

**Negative:**
- All data access functions require the `tenant_id` to be threaded through the call stack
- Slightly more verbose query construction

## Enforcement

The archgate rule for this ADR will warn (not error) on `Repo.all(` or `Repo.get(` calls that do not have `tenant_id` within 10 lines, to support incremental adoption.

`Repo.get_by(` is explicitly permitted without this check because it typically includes field-specific lookup that scopes the query appropriately.
