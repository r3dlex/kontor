import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

const { mockGet } = vi.hoisted(() => ({
  mockGet: vi.fn()
}))

vi.mock('@/api', () => ({
  default: {
    get: mockGet
  }
}))

import { useSearchStore } from '@/stores/search'

describe('search store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('initial state', () => {
    it('results is empty array', () => {
      const store = useSearchStore()
      expect(store.results).toEqual([])
    })

    it('loading is false', () => {
      const store = useSearchStore()
      expect(store.loading).toBe(false)
    })

    it('query is empty string', () => {
      const store = useSearchStore()
      expect(store.query).toBe('')
    })
  })

  describe('search', () => {
    it('sets query to the provided text', async () => {
      mockGet.mockResolvedValueOnce({ data: { results: [] } })
      const store = useSearchStore()
      await store.search('hello')
      expect(store.query).toBe('hello')
    })

    it('sets loading to true while request is in-flight', async () => {
      let resolve
      mockGet.mockReturnValueOnce(new Promise(r => { resolve = r }))
      const store = useSearchStore()
      const promise = store.search('test')
      expect(store.loading).toBe(true)
      resolve({ data: { results: [] } })
      await promise
    })

    it('sets loading back to false after request completes', async () => {
      mockGet.mockResolvedValueOnce({ data: { results: [] } })
      const store = useSearchStore()
      await store.search('test')
      expect(store.loading).toBe(false)
    })

    it('calls api.get with correct params', async () => {
      mockGet.mockResolvedValueOnce({ data: { results: [] } })
      const store = useSearchStore()
      await store.search('my query')
      expect(mockGet).toHaveBeenCalledWith('/search', { params: { q: 'my query' } })
    })

    it('populates results from response', async () => {
      const results = [
        { id: 1, subject: 'Thread A', type: 'thread', similarity_score: 0.9 }
      ]
      mockGet.mockResolvedValueOnce({ data: { results } })
      const store = useSearchStore()
      await store.search('test')
      expect(store.results).toEqual(results)
    })

    it('sets loading false even when request fails', async () => {
      mockGet.mockRejectedValueOnce(new Error('Network error'))
      const store = useSearchStore()
      try { await store.search('fail') } catch {}
      expect(store.loading).toBe(false)
    })
  })
})
