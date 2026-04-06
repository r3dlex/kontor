import { defineConfig } from 'archgate'

export default defineConfig({
  adrDir: '.archgate/adrs',
  failOn: 'error',
  ignore: ['_build/**', 'deps/**', 'node_modules/**', '.elixir_ls/**']
})
