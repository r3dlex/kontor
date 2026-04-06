import { defineRule, type RuleContext } from 'archgate'

/**
 * ARCH-001: Himalaya as sole email transport
 *
 * No file in lib/kontor/mail/ or lib/kontor/mcp/ should:
 * - Import :gen_tcp or :ssl (raw socket modules)
 * - Contain "IMAP" or "SMTP" string literals used as protocol markers
 *
 * Exception: lib/kontor/mcp/himalaya_client.ex is the designated integration
 * point and is excluded from these checks.
 */
export default defineRule({
  id: 'ARCH-001',
  description: 'Himalaya must be the sole email transport — no direct IMAP/SMTP/gen_tcp in mail or MCP modules',
  files: ['lib/kontor/mail/**/*.ex', 'lib/kontor/mcp/**/*.ex'],

  check(ctx: RuleContext) {
    const { file, content, path } = ctx

    // Exception: himalaya_client.ex is the designated MCP wrapper
    if (path.endsWith('himalaya_client.ex')) {
      return
    }

    // Check for raw socket imports
    if (/:gen_tcp/.test(content)) {
      ctx.error(
        `ARCH-001: Direct use of :gen_tcp found in ${path}. ` +
        'All email transport must go through Himalaya MCP (himalaya_client.ex).'
      )
    }

    if (/:ssl/.test(content)) {
      ctx.error(
        `ARCH-001: Direct use of :ssl found in ${path}. ` +
        'All email transport must go through Himalaya MCP (himalaya_client.ex).'
      )
    }

    // Check for IMAP/SMTP string literals used as protocol markers
    // Match quoted strings containing IMAP or SMTP (not inside comments)
    const lines = content.split('\n')
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const lineNumber = i + 1

      // Skip comment lines
      if (/^\s*#/.test(line)) continue

      // Check for IMAP or SMTP as string literals (quoted)
      if (/"IMAP"/.test(line) || /"SMTP"/.test(line)) {
        ctx.error(
          `ARCH-001: IMAP/SMTP string literal found at ${path}:${lineNumber}. ` +
          'Protocol identifiers must not appear in mail/mcp modules outside himalaya_client.ex.'
        )
      }
    }
  }
})
