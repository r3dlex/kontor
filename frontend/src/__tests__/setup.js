import { vi } from 'vitest'

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
