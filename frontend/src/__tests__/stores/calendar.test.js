import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

const { mockGet, mockPost, mockPatch } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPost: vi.fn(),
  mockPatch: vi.fn()
}))

vi.mock('@/api', () => ({
  default: {
    defaults: { headers: { common: {} } },
    get: mockGet,
    post: mockPost,
    patch: mockPatch
  }
}))

vi.mock('@/router', () => ({
  default: { push: vi.fn() }
}))

import { useCalendarStore } from '@/stores/calendar'

describe('calendar store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('fetchToday', () => {
    it('calls GET /calendar/today', async () => {
      mockGet.mockResolvedValueOnce({ data: { events: [] } })
      const store = useCalendarStore()
      await store.fetchToday()
      expect(mockGet).toHaveBeenCalledWith('/calendar/today')
    })

    it('populates todayEvents from the response', async () => {
      const fakeEvents = [
        { id: 1, title: 'Standup', start_time: '2026-04-06T09:00:00Z' },
        { id: 2, title: 'Review', start_time: '2026-04-06T14:00:00Z' }
      ]
      mockGet.mockResolvedValueOnce({ data: { events: fakeEvents } })
      const store = useCalendarStore()
      await store.fetchToday()
      expect(store.todayEvents).toEqual(fakeEvents)
    })

    it('sets loading to true while fetching and false after', async () => {
      let resolveFetch
      mockGet.mockReturnValueOnce(new Promise((resolve) => { resolveFetch = resolve }))
      const store = useCalendarStore()
      const fetchPromise = store.fetchToday()
      expect(store.loading).toBe(true)
      resolveFetch({ data: { events: [] } })
      await fetchPromise
      expect(store.loading).toBe(false)
    })

    it('sets loading to false on error', async () => {
      mockGet.mockRejectedValueOnce({ response: { data: { error: 'Server error' } } })
      const store = useCalendarStore()
      await store.fetchToday()
      expect(store.loading).toBe(false)
    })

    it('sets error message from response on failure', async () => {
      mockGet.mockRejectedValueOnce({ response: { data: { error: 'Forbidden' } } })
      const store = useCalendarStore()
      await store.fetchToday()
      expect(store.error).toBe('Forbidden')
    })

    it('sets generic error message when no response error', async () => {
      mockGet.mockRejectedValueOnce(new Error('Network error'))
      const store = useCalendarStore()
      await store.fetchToday()
      expect(store.error).toBe('Failed to fetch calendar')
    })

    it('clears error before fetching', async () => {
      mockGet.mockResolvedValueOnce({ data: { events: [] } })
      const store = useCalendarStore()
      store.error = 'old error'
      await store.fetchToday()
      expect(store.error).toBeNull()
    })
  })

  describe('fetchBriefing', () => {
    it('calls GET /calendar/briefing/:eventId', async () => {
      const event = { id: 5, title: 'Board Meeting' }
      mockGet.mockResolvedValueOnce({ data: { event } })
      const store = useCalendarStore()
      await store.fetchBriefing(5)
      expect(mockGet).toHaveBeenCalledWith('/calendar/briefing/5')
    })

    it('sets selectedEvent from the response', async () => {
      const event = { id: 5, title: 'Board Meeting' }
      mockGet.mockResolvedValueOnce({ data: { event } })
      const store = useCalendarStore()
      await store.fetchBriefing(5)
      expect(store.selectedEvent).toEqual(event)
    })

    it('returns the event on success', async () => {
      const event = { id: 5, title: 'Board Meeting' }
      mockGet.mockResolvedValueOnce({ data: { event } })
      const store = useCalendarStore()
      const result = await store.fetchBriefing(5)
      expect(result).toEqual(event)
    })

    it('returns null on error', async () => {
      mockGet.mockRejectedValueOnce(new Error('Not found'))
      const store = useCalendarStore()
      const result = await store.fetchBriefing(999)
      expect(result).toBeNull()
    })

    it('sets error on failure', async () => {
      mockGet.mockRejectedValueOnce(new Error('Not found'))
      const store = useCalendarStore()
      await store.fetchBriefing(999)
      expect(store.error).toBe('Failed to fetch briefing')
    })
  })

  describe('refreshBriefing', () => {
    it('calls POST /calendar/briefing/:eventId/refresh', async () => {
      const event = { id: 3, title: 'Updated Event' }
      mockPost.mockResolvedValueOnce({ data: { event } })
      const store = useCalendarStore()
      await store.refreshBriefing(3)
      expect(mockPost).toHaveBeenCalledWith('/calendar/briefing/3/refresh')
    })

    it('updates the event in todayEvents array in-place', async () => {
      const updated = { id: 3, title: 'Updated Event' }
      mockPost.mockResolvedValueOnce({ data: { event: updated } })
      const store = useCalendarStore()
      store.todayEvents = [
        { id: 3, title: 'Original Event' },
        { id: 4, title: 'Other Event' }
      ]
      await store.refreshBriefing(3)
      expect(store.todayEvents[0]).toEqual(updated)
      expect(store.todayEvents[1].id).toBe(4)
    })

    it('updates selectedEvent when it matches', async () => {
      const updated = { id: 3, title: 'Updated Event' }
      mockPost.mockResolvedValueOnce({ data: { event: updated } })
      const store = useCalendarStore()
      store.selectedEvent = { id: 3, title: 'Original Event' }
      store.todayEvents = [{ id: 3, title: 'Original Event' }]
      await store.refreshBriefing(3)
      expect(store.selectedEvent).toEqual(updated)
    })

    it('does not update selectedEvent when id does not match', async () => {
      const updated = { id: 4, title: 'Updated Other' }
      mockPost.mockResolvedValueOnce({ data: { event: updated } })
      const store = useCalendarStore()
      store.selectedEvent = { id: 3, title: 'My Event' }
      store.todayEvents = [{ id: 4, title: 'Other Event' }]
      await store.refreshBriefing(4)
      expect(store.selectedEvent.id).toBe(3)
    })

    it('returns the updated event on success', async () => {
      const updated = { id: 3, title: 'Updated Event' }
      mockPost.mockResolvedValueOnce({ data: { event: updated } })
      const store = useCalendarStore()
      store.todayEvents = [{ id: 3, title: 'Original' }]
      const result = await store.refreshBriefing(3)
      expect(result).toEqual(updated)
    })

    it('returns null on error', async () => {
      mockPost.mockRejectedValueOnce(new Error('Server error'))
      const store = useCalendarStore()
      const result = await store.refreshBriefing(3)
      expect(result).toBeNull()
    })

    it('sets error on failure', async () => {
      mockPost.mockRejectedValueOnce(new Error('Server error'))
      const store = useCalendarStore()
      await store.refreshBriefing(3)
      expect(store.error).toBe('Failed to refresh briefing')
    })
  })

  describe('createEvent', () => {
    it('calls POST /calendar/events with attrs', async () => {
      const attrs = { title: 'New Meeting', start_time: '2026-04-06T10:00:00Z' }
      const event = { id: 10, ...attrs }
      mockPost.mockResolvedValueOnce({ data: { event } })
      const store = useCalendarStore()
      await store.createEvent(attrs)
      expect(mockPost).toHaveBeenCalledWith('/calendar/events', attrs)
    })

    it('adds the new event to todayEvents', async () => {
      const event = { id: 10, title: 'New Meeting' }
      mockPost.mockResolvedValueOnce({ data: { event } })
      const store = useCalendarStore()
      store.todayEvents = [{ id: 1, title: 'Existing' }]
      await store.createEvent({ title: 'New Meeting' })
      expect(store.todayEvents).toHaveLength(2)
      expect(store.todayEvents[1]).toEqual(event)
    })

    it('returns success and event on success', async () => {
      const event = { id: 10, title: 'New Meeting' }
      mockPost.mockResolvedValueOnce({ data: { event } })
      const store = useCalendarStore()
      const result = await store.createEvent({ title: 'New Meeting' })
      expect(result).toEqual({ success: true, event })
    })

    it('returns failure and error message on error', async () => {
      mockPost.mockRejectedValueOnce({ response: { data: { error: 'Invalid attrs' } } })
      const store = useCalendarStore()
      const result = await store.createEvent({})
      expect(result.success).toBe(false)
      expect(result.error).toBe('Invalid attrs')
    })

    it('sets error on failure', async () => {
      mockPost.mockRejectedValueOnce(new Error('Network error'))
      const store = useCalendarStore()
      await store.createEvent({})
      expect(store.error).toBe('Failed to create event')
    })
  })

  describe('updateEvent', () => {
    it('calls PATCH /calendar/events/:id with attrs', async () => {
      const attrs = { title: 'Updated Meeting' }
      const event = { id: 7, ...attrs }
      mockPatch.mockResolvedValueOnce({ data: { event } })
      const store = useCalendarStore()
      await store.updateEvent(7, attrs)
      expect(mockPatch).toHaveBeenCalledWith('/calendar/events/7', attrs)
    })

    it('updates the event in todayEvents in-place', async () => {
      const updated = { id: 7, title: 'Updated Meeting' }
      mockPatch.mockResolvedValueOnce({ data: { event: updated } })
      const store = useCalendarStore()
      store.todayEvents = [
        { id: 7, title: 'Original Meeting' },
        { id: 8, title: 'Other' }
      ]
      await store.updateEvent(7, { title: 'Updated Meeting' })
      expect(store.todayEvents[0]).toEqual(updated)
      expect(store.todayEvents[1].id).toBe(8)
    })

    it('returns success and event on success', async () => {
      const event = { id: 7, title: 'Updated Meeting' }
      mockPatch.mockResolvedValueOnce({ data: { event } })
      const store = useCalendarStore()
      store.todayEvents = [{ id: 7, title: 'Original' }]
      const result = await store.updateEvent(7, { title: 'Updated Meeting' })
      expect(result).toEqual({ success: true, event })
    })

    it('returns failure and error on error', async () => {
      mockPatch.mockRejectedValueOnce({ response: { data: { error: 'Not found' } } })
      const store = useCalendarStore()
      const result = await store.updateEvent(999, {})
      expect(result.success).toBe(false)
      expect(result.error).toBe('Not found')
    })

    it('sets error on failure', async () => {
      mockPatch.mockRejectedValueOnce(new Error('Network error'))
      const store = useCalendarStore()
      await store.updateEvent(7, {})
      expect(store.error).toBe('Failed to update event')
    })
  })

  describe('upcomingEvents getter', () => {
    it('returns events with start_time in the future', () => {
      const store = useCalendarStore()
      const future = new Date(Date.now() + 3600000).toISOString()
      const past = new Date(Date.now() - 3600000).toISOString()
      store.todayEvents = [
        { id: 1, start_time: future },
        { id: 2, start_time: past }
      ]
      expect(store.upcomingEvents).toHaveLength(1)
      expect(store.upcomingEvents[0].id).toBe(1)
    })

    it('returns empty array when no upcoming events', () => {
      const store = useCalendarStore()
      const past = new Date(Date.now() - 3600000).toISOString()
      store.todayEvents = [{ id: 1, start_time: past }]
      expect(store.upcomingEvents).toHaveLength(0)
    })
  })

  describe('pastEvents getter', () => {
    it('returns events with start_time in the past', () => {
      const store = useCalendarStore()
      const future = new Date(Date.now() + 3600000).toISOString()
      const past = new Date(Date.now() - 3600000).toISOString()
      store.todayEvents = [
        { id: 1, start_time: future },
        { id: 2, start_time: past }
      ]
      expect(store.pastEvents).toHaveLength(1)
      expect(store.pastEvents[0].id).toBe(2)
    })

    it('returns empty array when all events are upcoming', () => {
      const store = useCalendarStore()
      const future = new Date(Date.now() + 3600000).toISOString()
      store.todayEvents = [{ id: 1, start_time: future }]
      expect(store.pastEvents).toHaveLength(0)
    })
  })
})
