import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

// Mock the api module before importing the store
vi.mock('@/api', () => ({
  default: {
    defaults: {
      headers: {
        common: {}
      }
    }
  }
}))

// Mock the router used by api/index.js
vi.mock('@/router', () => ({
  default: { push: vi.fn() }
}))

import { useAuthStore } from '@/stores/auth'
import api from '@/api'

describe('auth store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.removeItem('kontor_token')
    localStorage.removeItem('kontor_user')
    // Reset the mocked headers object
    api.defaults.headers.common = {}
  })

  describe('setAuth', () => {
    it('stores token in localStorage', () => {
      const store = useAuthStore()
      store.setAuth('test-token-123', { id: 1, name: 'Alice' })
      expect(localStorage.getItem('kontor_token')).toBe('test-token-123')
    })

    it('stores user as JSON in localStorage', () => {
      const store = useAuthStore()
      const user = { id: 1, name: 'Alice', email: 'alice@example.com' }
      store.setAuth('tok', user)
      expect(JSON.parse(localStorage.getItem('kontor_user'))).toEqual(user)
    })

    it('sets axios Authorization header with Bearer token', () => {
      const store = useAuthStore()
      store.setAuth('my-token', { id: 1 })
      expect(api.defaults.headers.common['Authorization']).toBe('Bearer my-token')
    })

    it('updates token ref on the store', () => {
      const store = useAuthStore()
      store.setAuth('abc123', { id: 2 })
      expect(store.token).toBe('abc123')
    })

    it('updates user ref on the store', () => {
      const store = useAuthStore()
      const user = { id: 2, name: 'Bob' }
      store.setAuth('tok', user)
      expect(store.user).toEqual(user)
    })
  })

  describe('clearAuth', () => {
    it('removes kontor_token from localStorage', () => {
      localStorage.setItem('kontor_token', 'existing-token')
      const store = useAuthStore()
      store.clearAuth()
      expect(localStorage.getItem('kontor_token')).toBeNull()
    })

    it('removes kontor_user from localStorage', () => {
      localStorage.setItem('kontor_user', JSON.stringify({ id: 1 }))
      const store = useAuthStore()
      store.clearAuth()
      expect(localStorage.getItem('kontor_user')).toBeNull()
    })

    it('deletes the Authorization header from axios', () => {
      api.defaults.headers.common['Authorization'] = 'Bearer old-token'
      const store = useAuthStore()
      store.clearAuth()
      expect(api.defaults.headers.common['Authorization']).toBeUndefined()
    })

    it('sets token ref to null', () => {
      const store = useAuthStore()
      store.setAuth('tok', { id: 1 })
      store.clearAuth()
      expect(store.token).toBeNull()
    })

    it('sets user ref to null', () => {
      const store = useAuthStore()
      store.setAuth('tok', { id: 1 })
      store.clearAuth()
      expect(store.user).toBeNull()
    })
  })

  describe('isAuthenticated', () => {
    it('returns false when no token is present', () => {
      const store = useAuthStore()
      expect(store.isAuthenticated).toBe(false)
    })

    it('returns true after setAuth is called with a token', () => {
      const store = useAuthStore()
      store.setAuth('valid-token', { id: 1 })
      expect(store.isAuthenticated).toBe(true)
    })

    it('returns false after clearAuth is called', () => {
      const store = useAuthStore()
      store.setAuth('valid-token', { id: 1 })
      store.clearAuth()
      expect(store.isAuthenticated).toBe(false)
    })
  })

  describe('initialization from localStorage', () => {
    it('reads token from localStorage on store creation', () => {
      localStorage.setItem('kontor_token', 'persisted-token')
      const store = useAuthStore()
      expect(store.token).toBe('persisted-token')
    })

    it('reads user from localStorage on store creation', () => {
      const user = { id: 5, name: 'Eve' }
      localStorage.setItem('kontor_user', JSON.stringify(user))
      const store = useAuthStore()
      expect(store.user).toEqual(user)
    })

    it('initializes with null token when localStorage is empty', () => {
      const store = useAuthStore()
      expect(store.token).toBeNull()
    })

    it('initializes with null user when localStorage is empty', () => {
      const store = useAuthStore()
      expect(store.user).toBeNull()
    })

    it('sets Authorization header on init when token exists in localStorage', () => {
      localStorage.setItem('kontor_token', 'init-token')
      useAuthStore()
      expect(api.defaults.headers.common['Authorization']).toBe('Bearer init-token')
    })

    it('does not set Authorization header when no token in localStorage', () => {
      useAuthStore()
      expect(api.defaults.headers.common['Authorization']).toBeUndefined()
    })
  })

  describe('setAuth overwrites existing auth', () => {
    it('overwrites existing token', () => {
      const store = useAuthStore()
      store.setAuth('first-token', { id: 1 })
      store.setAuth('second-token', { id: 2 })
      expect(store.token).toBe('second-token')
      expect(localStorage.getItem('kontor_token')).toBe('second-token')
    })

    it('overwrites existing user', () => {
      const store = useAuthStore()
      store.setAuth('tok', { id: 1, name: 'Alice' })
      store.setAuth('tok2', { id: 2, name: 'Bob' })
      expect(store.user).toEqual({ id: 2, name: 'Bob' })
    })

    it('updates Authorization header to new token', () => {
      const store = useAuthStore()
      store.setAuth('old-token', { id: 1 })
      store.setAuth('new-token', { id: 1 })
      expect(api.defaults.headers.common['Authorization']).toBe('Bearer new-token')
    })
  })

  describe('clearAuth is idempotent', () => {
    it('can be called multiple times without error', () => {
      const store = useAuthStore()
      expect(() => {
        store.clearAuth()
        store.clearAuth()
      }).not.toThrow()
    })

    it('token remains null after second clearAuth', () => {
      const store = useAuthStore()
      store.clearAuth()
      store.clearAuth()
      expect(store.token).toBeNull()
    })
  })
})
