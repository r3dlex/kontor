import { defineRule, type RuleContext } from 'archgate'

/**
 * ARCH-004: Skills are markdown prompt templates, not compiled code
 *
 * Every .md file in priv/skills/ must have valid YAML frontmatter with
 * required fields: name, namespace, version, author. Missing fields are errors.
 */
export default defineRule({
  id: 'ARCH-004',
  description: 'All skill .md files must have valid YAML frontmatter with name, namespace, version, and author fields',
  files: ['priv/skills/**/*.md'],

  check(ctx: RuleContext) {
    const { content, path } = ctx

    // Check for YAML frontmatter block
    if (!content.startsWith('---')) {
      ctx.error(
        `ARCH-004: ${path} is missing YAML frontmatter. ` +
        'All skill files must begin with a --- delimited YAML frontmatter block.'
      )
      return
    }

    // Extract frontmatter block between first and second ---
    const endIndex = content.indexOf('---', 3)
    if (endIndex === -1) {
      ctx.error(
        `ARCH-004: ${path} has an unclosed YAML frontmatter block. ` +
        'Frontmatter must be closed with a second --- delimiter.'
      )
      return
    }

    const frontmatter = content.slice(3, endIndex)

    // Check for required fields
    const requiredFields = ['name', 'namespace', 'version', 'author'] as const

    for (const field of requiredFields) {
      // Match "field:" at the start of a line (with optional whitespace)
      const fieldPattern = new RegExp(`^\\s*${field}\\s*:`, 'm')
      if (!fieldPattern.test(frontmatter)) {
        ctx.error(
          `ARCH-004: ${path} is missing required frontmatter field: "${field}". ` +
          `All skill files must declare name, namespace, version, and author in their YAML frontmatter.`
        )
      }
    }

    // Validate that version is a number (not a string)
    const versionMatch = frontmatter.match(/^\s*version\s*:\s*(.+)$/m)
    if (versionMatch) {
      const versionValue = versionMatch[1].trim()
      if (!/^\d+$/.test(versionValue)) {
        ctx.error(
          `ARCH-004: ${path} has an invalid version value: "${versionValue}". ` +
          'Version must be a positive integer.'
        )
      }
    }

    // Validate that author is not empty
    const authorMatch = frontmatter.match(/^\s*author\s*:\s*(.+)$/m)
    if (authorMatch) {
      const authorValue = authorMatch[1].trim()
      if (!authorValue || authorValue === 'null' || authorValue === '~') {
        ctx.error(
          `ARCH-004: ${path} has an empty or null author field. ` +
          'Author must be "llm" or a valid GitHub username.'
        )
      }
    }
  }
})
