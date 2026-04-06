import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

const { mockGet, mockPost } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPost: vi.fn()
}))

vi.mock('@/api', () => ({
  default: {
    defaults: { headers: { common: {} } },
    get: mockGet,
    post: mockPost
  }
}))

vi.mock('@/router', () => ({
  default: { push: vi.fn() }
}))

import { useMailboxesStore } from '@/stores/mailboxes'

describe('mailboxes store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('fetchMailboxes', () => {
    it('calls GET /mailboxes', async () => {
      mockGet.mockResolvedValueOnce({ data: { mailboxes: [] } })
      const store = useMailboxesStore()
      await store.fetchMailboxes()
      expect(mockGet).toHaveBeenCalledWith('/mailboxes')
    })

    it('populates mailboxes from the response', async () => {
      const fakeMailboxes = [
        { id: 1, email: 'alice@example.com' },
        { id: 2, email: 'bob@example.com' }
      ]
      mockGet.mockResolvedValueOnce({ data: { mailboxes: fakeMailboxes } })
      const store = useMailboxesStore()
      await store.fetchMailboxes()
      expect(store.mailboxes).toEqual(fakeMailboxes)
    })

    it('auto-selects the first mailbox when none is selected', async () => {
      const fakeMailboxes = [
        { id: 1, email: 'alice@example.com' },
        { id: 2, email: 'bob@example.com' }
      ]
      mockGet.mockResolvedValueOnce({ data: { mailboxes: fakeMailboxes } })
      const store = useMailboxesStore()
      await store.fetchMailboxes()
      expect(store.selectedMailboxId).toBe(1)
    })

    it('does not change selectedMailboxId when one is already set', async () => {
      const fakeMailboxes = [
        { id: 1, email: 'alice@example.com' },
        { id: 2, email: 'bob@example.com' }
      ]
      mockGet.mockResolvedValueOnce({ data: { mailboxes: fakeMailboxes } })
      const store = useMailboxesStore()
      store.selectedMailboxId = 2
      await store.fetchMailboxes()
      expect(store.selectedMailboxId).toBe(2)
    })

    it('handles missing mailboxes key gracefully', async () => {
      mockGet.mockResolvedValueOnce({ data: {} })
      const store = useMailboxesStore()
      await store.fetchMailboxes()
      expect(store.mailboxes).toEqual([])
    })

    it('sets loading to true while fetching and false after', async () => {
      let resolveFetch
      mockGet.mockReturnValueOnce(new Promise((resolve) => { resolveFetch = resolve }))
      const store = useMailboxesStore()
      const fetchPromise = store.fetchMailboxes()
      expect(store.loading).toBe(true)
      resolveFetch({ data: { mailboxes: [] } })
      await fetchPromise
      expect(store.loading).toBe(false)
    })

    it('sets loading to false on error', async () => {
      mockGet.mockRejectedValueOnce({ response: { data: { error: 'Server error' } } })
      const store = useMailboxesStore()
      await store.fetchMailboxes()
      expect(store.loading).toBe(false)
    })

    it('sets error message from response on failure', async () => {
      mockGet.mockRejectedValueOnce({ response: { data: { error: 'Unauthorized' } } })
      const store = useMailboxesStore()
      await store.fetchMailboxes()
      expect(store.error).toBe('Unauthorized')
    })

    it('sets generic error message when no response error', async () => {
      mockGet.mockRejectedValueOnce(new Error('Network error'))
      const store = useMailboxesStore()
      await store.fetchMailboxes()
      expect(store.error).toBe('Failed to fetch mailboxes')
    })

    it('clears error before fetching', async () => {
      mockGet.mockResolvedValueOnce({ data: { mailboxes: [] } })
      const store = useMailboxesStore()
      store.error = 'old error'
      await store.fetchMailboxes()
      expect(store.error).toBeNull()
    })
  })

  describe('selectMailbox', () => {
    it('updates selectedMailboxId', () => {
      const store = useMailboxesStore()
      store.selectMailbox(42)
      expect(store.selectedMailboxId).toBe(42)
    })

    it('can change from one mailbox to another', () => {
      const store = useMailboxesStore()
      store.selectedMailboxId = 1
      store.selectMailbox(2)
      expect(store.selectedMailboxId).toBe(2)
    })
  })

  describe('createMailbox', () => {
    it('calls POST /mailboxes with attrs', async () => {
      const attrs = { email: 'new@example.com', provider: 'google' }
      const mailbox = { id: 3, ...attrs }
      mockPost.mockResolvedValueOnce({ data: { mailbox } })
      const store = useMailboxesStore()
      await store.createMailbox(attrs)
      expect(mockPost).toHaveBeenCalledWith('/mailboxes', attrs)
    })

    it('adds the new mailbox to the mailboxes array', async () => {
      const mailbox = { id: 3, email: 'new@example.com' }
      mockPost.mockResolvedValueOnce({ data: { mailbox } })
      const store = useMailboxesStore()
      store.mailboxes = [{ id: 1, email: 'existing@example.com' }]
      await store.createMailbox({ email: 'new@example.com' })
      expect(store.mailboxes).toHaveLength(2)
      expect(store.mailboxes[1]).toEqual(mailbox)
    })

    it('returns success and mailbox on success', async () => {
      const mailbox = { id: 3, email: 'new@example.com' }
      mockPost.mockResolvedValueOnce({ data: { mailbox } })
      const store = useMailboxesStore()
      const result = await store.createMailbox({ email: 'new@example.com' })
      expect(result).toEqual({ success: true, mailbox })
    })

    it('returns failure and error message on error', async () => {
      mockPost.mockRejectedValueOnce({ response: { data: { error: 'Invalid email' } } })
      const store = useMailboxesStore()
      const result = await store.createMailbox({ email: 'bad' })
      expect(result.success).toBe(false)
      expect(result.error).toBe('Invalid email')
    })

    it('sets error on failure', async () => {
      mockPost.mockRejectedValueOnce(new Error('Network error'))
      const store = useMailboxesStore()
      await store.createMailbox({})
      expect(store.error).toBe('Failed to create mailbox')
    })
  })

  describe('selectedMailbox getter', () => {
    it('returns the mailbox matching selectedMailboxId', () => {
      const store = useMailboxesStore()
      store.mailboxes = [
        { id: 1, email: 'alice@example.com' },
        { id: 2, email: 'bob@example.com' }
      ]
      store.selectedMailboxId = 2
      expect(store.selectedMailbox).toEqual({ id: 2, email: 'bob@example.com' })
    })

    it('returns undefined when selectedMailboxId is null', () => {
      const store = useMailboxesStore()
      store.mailboxes = [{ id: 1, email: 'alice@example.com' }]
      store.selectedMailboxId = null
      expect(store.selectedMailbox).toBeUndefined()
    })

    it('returns undefined when no mailbox matches', () => {
      const store = useMailboxesStore()
      store.mailboxes = [{ id: 1, email: 'alice@example.com' }]
      store.selectedMailboxId = 999
      expect(store.selectedMailbox).toBeUndefined()
    })
  })

  describe('hasMailboxes getter', () => {
    it('returns true when mailboxes array is non-empty', () => {
      const store = useMailboxesStore()
      store.mailboxes = [{ id: 1, email: 'alice@example.com' }]
      expect(store.hasMailboxes).toBe(true)
    })

    it('returns false when mailboxes array is empty', () => {
      const store = useMailboxesStore()
      store.mailboxes = []
      expect(store.hasMailboxes).toBe(false)
    })
  })
})
