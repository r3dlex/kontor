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

import { useContactsStore } from '@/stores/contacts'

describe('contacts store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('fetchContacts', () => {
    it('calls GET /contacts', async () => {
      mockGet.mockResolvedValueOnce({ data: { contacts: [] } })
      const store = useContactsStore()
      await store.fetchContacts()
      expect(mockGet).toHaveBeenCalledWith('/contacts')
    })

    it('populates contacts from the response', async () => {
      const fakeContacts = [
        { id: 1, display_name: 'Alice', importance_weight: 0.9 },
        { id: 2, display_name: 'Bob', importance_weight: 0.5 }
      ]
      mockGet.mockResolvedValueOnce({ data: { contacts: fakeContacts } })
      const store = useContactsStore()
      await store.fetchContacts()
      expect(store.contacts).toEqual(fakeContacts)
    })

    it('sets loading to true while fetching and false after', async () => {
      let resolveFetch
      mockGet.mockReturnValueOnce(new Promise((resolve) => { resolveFetch = resolve }))
      const store = useContactsStore()
      const fetchPromise = store.fetchContacts()
      expect(store.loading).toBe(true)
      resolveFetch({ data: { contacts: [] } })
      await fetchPromise
      expect(store.loading).toBe(false)
    })

    it('sets loading to false on error', async () => {
      mockGet.mockRejectedValueOnce({ response: { data: { error: 'Server error' } } })
      const store = useContactsStore()
      await store.fetchContacts()
      expect(store.loading).toBe(false)
    })

    it('sets error message on failure', async () => {
      mockGet.mockRejectedValueOnce({ response: { data: { error: 'Unauthorized' } } })
      const store = useContactsStore()
      await store.fetchContacts()
      expect(store.error).toBe('Unauthorized')
    })

    it('sets generic error message when response error is missing', async () => {
      mockGet.mockRejectedValueOnce(new Error('Network error'))
      const store = useContactsStore()
      await store.fetchContacts()
      expect(store.error).toBe('Failed to fetch contacts')
    })

    it('clears error before fetching', async () => {
      mockGet.mockResolvedValueOnce({ data: { contacts: [] } })
      const store = useContactsStore()
      store.error = 'old error'
      await store.fetchContacts()
      expect(store.error).toBeNull()
    })
  })

  describe('fetchContact', () => {
    it('calls GET /contacts/:id', async () => {
      const contact = { id: 1, display_name: 'Alice' }
      mockGet.mockResolvedValueOnce({ data: { contact } })
      const store = useContactsStore()
      await store.fetchContact(1)
      expect(mockGet).toHaveBeenCalledWith('/contacts/1')
    })

    it('sets selectedContact from the response', async () => {
      const contact = { id: 1, display_name: 'Alice' }
      mockGet.mockResolvedValueOnce({ data: { contact } })
      const store = useContactsStore()
      await store.fetchContact(1)
      expect(store.selectedContact).toEqual(contact)
    })

    it('returns the contact on success', async () => {
      const contact = { id: 1, display_name: 'Alice' }
      mockGet.mockResolvedValueOnce({ data: { contact } })
      const store = useContactsStore()
      const result = await store.fetchContact(1)
      expect(result).toEqual(contact)
    })

    it('returns null on error', async () => {
      mockGet.mockRejectedValueOnce({ response: { data: { error: 'Not found' } } })
      const store = useContactsStore()
      const result = await store.fetchContact(999)
      expect(result).toBeNull()
    })

    it('sets error on failure', async () => {
      mockGet.mockRejectedValueOnce({ response: { data: { error: 'Not found' } } })
      const store = useContactsStore()
      await store.fetchContact(999)
      expect(store.error).toBe('Not found')
    })
  })

  describe('fetchGraph', () => {
    it('calls GET /contacts/graph', async () => {
      mockGet.mockResolvedValueOnce({ data: { nodes: [], edges: [] } })
      const store = useContactsStore()
      await store.fetchGraph()
      expect(mockGet).toHaveBeenCalledWith('/contacts/graph')
    })

    it('sets graph from the response', async () => {
      const graphData = { nodes: [{ id: 1 }], edges: [] }
      mockGet.mockResolvedValueOnce({ data: graphData })
      const store = useContactsStore()
      await store.fetchGraph()
      expect(store.graph).toEqual(graphData)
    })

    it('returns the graph data on success', async () => {
      const graphData = { nodes: [], edges: [] }
      mockGet.mockResolvedValueOnce({ data: graphData })
      const store = useContactsStore()
      const result = await store.fetchGraph()
      expect(result).toEqual(graphData)
    })

    it('returns null on error', async () => {
      mockGet.mockRejectedValueOnce(new Error('Network error'))
      const store = useContactsStore()
      const result = await store.fetchGraph()
      expect(result).toBeNull()
    })

    it('sets error message on failure', async () => {
      mockGet.mockRejectedValueOnce(new Error('Network error'))
      const store = useContactsStore()
      await store.fetchGraph()
      expect(store.error).toBe('Failed to fetch contact graph')
    })
  })

  describe('refreshContact', () => {
    it('calls POST /contacts/:id/refresh', async () => {
      const contact = { id: 1, display_name: 'Alice Updated' }
      mockPost.mockResolvedValueOnce({ data: { contact } })
      const store = useContactsStore()
      await store.refreshContact(1)
      expect(mockPost).toHaveBeenCalledWith('/contacts/1/refresh')
    })

    it('updates the contact in the contacts array in-place', async () => {
      const original = { id: 1, display_name: 'Alice' }
      const updated = { id: 1, display_name: 'Alice Updated' }
      mockPost.mockResolvedValueOnce({ data: { contact: updated } })
      const store = useContactsStore()
      store.contacts = [original, { id: 2, display_name: 'Bob' }]
      await store.refreshContact(1)
      expect(store.contacts[0]).toEqual(updated)
      expect(store.contacts[1].id).toBe(2)
    })

    it('updates selectedContact when it matches the refreshed id', async () => {
      const updated = { id: 1, display_name: 'Alice Updated' }
      mockPost.mockResolvedValueOnce({ data: { contact: updated } })
      const store = useContactsStore()
      store.selectedContact = { id: 1, display_name: 'Alice' }
      store.contacts = [{ id: 1, display_name: 'Alice' }]
      await store.refreshContact(1)
      expect(store.selectedContact).toEqual(updated)
    })

    it('does not update selectedContact when id does not match', async () => {
      const updated = { id: 2, display_name: 'Bob Updated' }
      mockPost.mockResolvedValueOnce({ data: { contact: updated } })
      const store = useContactsStore()
      store.selectedContact = { id: 1, display_name: 'Alice' }
      store.contacts = [{ id: 2, display_name: 'Bob' }]
      await store.refreshContact(2)
      expect(store.selectedContact.id).toBe(1)
    })

    it('returns the updated contact on success', async () => {
      const updated = { id: 1, display_name: 'Alice Updated' }
      mockPost.mockResolvedValueOnce({ data: { contact: updated } })
      const store = useContactsStore()
      store.contacts = [{ id: 1, display_name: 'Alice' }]
      const result = await store.refreshContact(1)
      expect(result).toEqual(updated)
    })

    it('returns null on error', async () => {
      mockPost.mockRejectedValueOnce(new Error('Server error'))
      const store = useContactsStore()
      const result = await store.refreshContact(1)
      expect(result).toBeNull()
    })

    it('sets error on failure', async () => {
      mockPost.mockRejectedValueOnce(new Error('Server error'))
      const store = useContactsStore()
      await store.refreshContact(1)
      expect(store.error).toBe('Failed to refresh contact')
    })
  })

  describe('contactById getter', () => {
    it('returns the contact with the matching id', () => {
      const store = useContactsStore()
      store.contacts = [
        { id: 1, display_name: 'Alice' },
        { id: 2, display_name: 'Bob' }
      ]
      expect(store.contactById(1)).toEqual({ id: 1, display_name: 'Alice' })
      expect(store.contactById(2)).toEqual({ id: 2, display_name: 'Bob' })
    })

    it('returns undefined when contact is not found', () => {
      const store = useContactsStore()
      store.contacts = [{ id: 1, display_name: 'Alice' }]
      expect(store.contactById(999)).toBeUndefined()
    })
  })

  describe('sortedContacts getter', () => {
    it('returns contacts sorted by importance_weight descending', () => {
      const store = useContactsStore()
      store.contacts = [
        { id: 1, importance_weight: 0.3 },
        { id: 2, importance_weight: 0.9 },
        { id: 3, importance_weight: 0.6 }
      ]
      const sorted = store.sortedContacts
      expect(sorted[0].id).toBe(2)
      expect(sorted[1].id).toBe(3)
      expect(sorted[2].id).toBe(1)
    })

    it('treats missing importance_weight as 0', () => {
      const store = useContactsStore()
      store.contacts = [
        { id: 1, importance_weight: 0.5 },
        { id: 2 }
      ]
      const sorted = store.sortedContacts
      expect(sorted[0].id).toBe(1)
      expect(sorted[1].id).toBe(2)
    })

    it('does not mutate the original contacts array', () => {
      const store = useContactsStore()
      store.contacts = [
        { id: 1, importance_weight: 0.3 },
        { id: 2, importance_weight: 0.9 }
      ]
      store.sortedContacts
      expect(store.contacts[0].id).toBe(1)
    })
  })
})
