import { defineRule, type RuleContext } from 'archgate'

/**
 * ARCH-002: All queries scoped by tenant_id
 *
 * Any file containing Repo.all( or Repo.get( (not Repo.get_by) must also
 * contain tenant_id within 10 lines of that call. Warn if not.
 */
export default defineRule({
  id: 'ARCH-002',
  description: 'All Repo.all/Repo.get calls must be scoped by tenant_id within 10 lines',
  files: ['lib/kontor/**/*.ex'],

  check(ctx: RuleContext) {
    const { content, path } = ctx
    const lines = content.split('\n')

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const lineNumber = i + 1

      // Skip comment lines
      if (/^\s*#/.test(line)) continue

      const hasRepoAll = /Repo\.all\(/.test(line)
      // Match Repo.get( but not Repo.get_by(
      const hasRepoGet = /Repo\.get\(/.test(line) && !/Repo\.get_by\(/.test(line)

      if (!hasRepoAll && !hasRepoGet) continue

      const callType = hasRepoAll ? 'Repo.all(' : 'Repo.get('

      // Check within 10 lines before and after for tenant_id
      const windowStart = Math.max(0, i - 10)
      const windowEnd = Math.min(lines.length - 1, i + 10)
      const window = lines.slice(windowStart, windowEnd + 1).join('\n')

      if (!/tenant_id/.test(window)) {
        ctx.warn(
          `ARCH-002: ${callType} at ${path}:${lineNumber} does not have tenant_id ` +
          'within 10 lines. All queries must be scoped by tenant_id to prevent ' +
          'cross-tenant data access. Consider using Repo.get_by with tenant_id.'
        )
      }
    }
  }
})
