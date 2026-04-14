import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src')
    }
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:4000',
        changeOrigin: true
      },
      '/socket': {
        target: 'ws://localhost:4000',
        ws: true
      }
    }
  },
  build: {
    outDir: '../priv/static',
    emptyOutDir: true
  },
  test: {
    environment: 'jsdom',
    environmentOptions: {
      jsdom: {
        url: 'http://localhost'
      }
    },
    globals: true,
    setupFiles: ['./vitest-setup.js', './src/__tests__/setup.js'],
    exclude: [
      'node_modules/**',
      'dist/**',
      'e2e/**'
    ],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      thresholds: {
        branches: 75,
        functions: 77,
        lines: 80,
        statements: 80
      },
      exclude: [
        'node_modules/**',
        'dist/**',
        '**/*.config.*',
        'e2e/**',
        'src/router/**',
        'src/api/**',
        'src/layouts/**',
        'src/main.*',
        'src/App.vue'
      ]
    }
  }
})
