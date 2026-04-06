import { defineStore } from 'pinia'
import api from '@/api'

export const useCalendarStore = defineStore('calendar', {
  state: () => ({
    todayEvents: [],
    selectedEvent: null,
    loading: false,
    error: null
  }),

  getters: {
    upcomingEvents: (state) => {
      const now = new Date()
      return state.todayEvents.filter(e => new Date(e.start_time) >= now)
    },
    pastEvents: (state) => {
      const now = new Date()
      return state.todayEvents.filter(e => new Date(e.start_time) < now)
    }
  },

  actions: {
    async fetchToday() {
      this.loading = true
      this.error = null
      try {
        const { data } = await api.get('/calendar/today')
        this.todayEvents = data.events
      } catch (err) {
        this.error = err.response?.data?.error || 'Failed to fetch calendar'
      } finally {
        this.loading = false
      }
    },

    async fetchBriefing(eventId) {
      try {
        const { data } = await api.get(`/calendar/briefing/${eventId}`)
        this.selectedEvent = data.event
        return data.event
      } catch (err) {
        this.error = 'Failed to fetch briefing'
        return null
      }
    },

    async refreshBriefing(eventId) {
      try {
        const { data } = await api.post(`/calendar/briefing/${eventId}/refresh`)
        const idx = this.todayEvents.findIndex(e => e.id === eventId)
        if (idx !== -1) this.todayEvents[idx] = data.event
        if (this.selectedEvent?.id === eventId) this.selectedEvent = data.event
        return data.event
      } catch (err) {
        this.error = 'Failed to refresh briefing'
        return null
      }
    },

    async createEvent(attrs) {
      try {
        const { data } = await api.post('/calendar/events', attrs)
        this.todayEvents.push(data.event)
        return { success: true, event: data.event }
      } catch (err) {
        this.error = err.response?.data?.error || 'Failed to create event'
        return { success: false, error: this.error }
      }
    },

    async updateEvent(id, attrs) {
      try {
        const { data } = await api.patch(`/calendar/events/${id}`, attrs)
        const idx = this.todayEvents.findIndex(e => e.id === id)
        if (idx !== -1) this.todayEvents[idx] = data.event
        return { success: true, event: data.event }
      } catch (err) {
        this.error = err.response?.data?.error || 'Failed to update event'
        return { success: false, error: this.error }
      }
    }
  }
})
