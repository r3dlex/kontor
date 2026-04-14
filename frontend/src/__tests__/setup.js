import { vi } from 'vitest'
import PrimeVue from 'primevue/config'
import Aura from '@primeuix/themes/aura'

// Node 22+ provides a native --localstorage-file based localStorage that
// may be incomplete. Override with a full in-memory implementation.
const store = {}
const localStorageMock = {
  getItem: (key) => store[key] ?? null,
  setItem: (key, value) => { store[key] = String(value) },
  removeItem: (key) => { delete store[key] },
  clear: () => { Object.keys(store).forEach(k => delete store[k]) },
  get length() { return Object.keys(store).length },
  key: (i) => Object.keys(store)[i] ?? null
}

vi.stubGlobal('localStorage', localStorageMock)

// Install PrimeVue globally for all tests with unstyled mode to avoid
// CSS conflicts in jsdom environment
export function installPrimeVue(app) {
  app.use(PrimeVue, {
    unstyled: true,
    theme: {
      preset: Aura,
      options: { darkModeSelector: '.dark' }
    }
  })
}
