import { defineRule, type RuleContext } from 'archgate'

/**
 * ARCH-005: Zero-install distribution via Burrito
 *
 * mix.exs must contain "burrito" in the releases/0 function and in deps.
 */
export default defineRule({
  id: 'ARCH-005',
  description: 'mix.exs must configure Burrito in both deps and releases/0',
  files: ['mix.exs'],

  check(ctx: RuleContext) {
    const { content, path } = ctx

    // Check that burrito appears in deps
    // Match {:burrito, ...} in the deps list
    if (!/:burrito/.test(content)) {
      ctx.error(
        `ARCH-005: ${path} does not list :burrito as a dependency. ` +
        'Burrito must be included in deps for zero-install binary distribution.'
      )
    }

    // Check that burrito appears in the releases configuration
    // The releases function should reference Burrito.wrap
    if (!/Burrito\.wrap/.test(content)) {
      ctx.error(
        `ARCH-005: ${path} does not reference Burrito.wrap in the releases configuration. ` +
        'The releases/0 function must include &Burrito.wrap/1 in its steps.'
      )
    }

    // Check that burrito targets are configured
    if (!/burrito:/.test(content) && !/burrito \[/.test(content)) {
      ctx.error(
        `ARCH-005: ${path} is missing Burrito targets configuration in releases/0. ` +
        'Expected a burrito: keyword with macos_arm, macos_x86, and linux_x86 targets.'
      )
    }

    // Verify at least one target is defined
    const hasTargets =
      /macos_arm/.test(content) ||
      /macos_x86/.test(content) ||
      /linux_x86/.test(content)

    if (!hasTargets) {
      ctx.error(
        `ARCH-005: ${path} has no Burrito targets defined. ` +
        'Expected targets: macos_arm, macos_x86, linux_x86.'
      )
    }
  }
})
