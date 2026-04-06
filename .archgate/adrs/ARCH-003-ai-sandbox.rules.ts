import { defineRule, type RuleContext } from 'archgate'

/**
 * ARCH-003: LLM actions must pass through AI Sandbox
 *
 * - lib/kontor/ai/pipeline.ex must reference "Sandbox" or "AI.Sandbox"
 * - Direct Req.get/Req.post calls outside minimax_client.ex and embeddings.ex are violations
 */
export default defineRule({
  id: 'ARCH-003',
  description: 'All LLM pipeline actions must pass through AI.Sandbox; direct Req calls are only permitted in minimax_client.ex and embeddings.ex',
  files: ['lib/kontor/ai/**/*.ex'],

  check(ctx: RuleContext) {
    const { content, path } = ctx

    // Rule 1: pipeline.ex must reference Sandbox
    if (path.endsWith('pipeline.ex')) {
      if (!/Sandbox|AI\.Sandbox/.test(content)) {
        ctx.error(
          `ARCH-003: ${path} does not reference Sandbox or AI.Sandbox. ` +
          'The AI pipeline must route all LLM-proposed actions through the Sandbox allowlist validator.'
        )
      }
    }

    // Rule 2: Direct Req.get/Req.post outside of permitted files
    const isPermittedHttpFile =
      path.endsWith('minimax_client.ex') ||
      path.endsWith('embeddings.ex')

    if (isPermittedHttpFile) return

    const lines = content.split('\n')
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const lineNumber = i + 1

      // Skip comment lines
      if (/^\s*#/.test(line)) continue

      if (/Req\.(get|post)\(/.test(line)) {
        ctx.error(
          `ARCH-003: Direct Req.get/Req.post call found at ${path}:${lineNumber}. ` +
          'Direct HTTP calls from AI modules are only permitted in minimax_client.ex and embeddings.ex. ' +
          'All other AI module HTTP interactions must go through the designated clients.'
        )
      }
    }
  }
})
