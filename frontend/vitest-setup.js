// vitest-setup.js — runs before ALL test modules are loaded.
// Primes jsdom with missing browser APIs that PrimeVue relies on,
// then registers PrimeVue globally so mount()ed components have it.
import PrimeVue from 'primevue/config'
import Aura from '@primeuix/themes/aura'

// --- ResizeObserver polyfill (used by PrimeVue Textarea) ---
if (typeof window.ResizeObserver === 'undefined') {
  window.ResizeObserver = class ResizeObserver {
    observe() {}
    unobserve() {}
    disconnect() {}
  }
}

// --- jsdom polyfills PrimeVue requires ---
if (typeof window.matchMedia !== 'function') {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    configurable: true,
    value: (query) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => true
    })
  })
}

// --- Register PrimeVue globally so every mount() gets it ---
const { config } = require('@vue/test-utils')
config.global.plugins = config.global.plugins || []
config.global.plugins.push([PrimeVue, {
  unstyled: true,
  theme: {
    preset: Aura,
    options: { darkModeSelector: '.dark' }
  }
}])
