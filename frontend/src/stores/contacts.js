import { defineStore } from 'pinia'
import api from '@/api'

export const useContactsStore = defineStore('contacts', {
  state: () => ({
    contacts: [],
    selectedContact: null,
    graph: null,
    loading: false,
    error: null
  }),

  getters: {
    contactById: (state) => (id) => state.contacts.find(c => c.id === id),
    sortedContacts: (state) => [...state.contacts].sort((a, b) =>
      (b.importance_weight || 0) - (a.importance_weight || 0)
    )
  },

  actions: {
    async fetchContacts() {
      this.loading = true
      this.error = null
      try {
        const { data } = await api.get('/contacts')
        this.contacts = data.contacts
      } catch (err) {
        this.error = err.response?.data?.error || 'Failed to fetch contacts'
      } finally {
        this.loading = false
      }
    },

    async fetchContact(id) {
      try {
        const { data } = await api.get(`/contacts/${id}`)
        this.selectedContact = data.contact
        return data.contact
      } catch (err) {
        this.error = err.response?.data?.error || 'Failed to fetch contact'
        return null
      }
    },

    async fetchGraph() {
      try {
        const { data } = await api.get('/contacts/graph')
        this.graph = data
        return data
      } catch (err) {
        this.error = 'Failed to fetch contact graph'
        return null
      }
    },

    async refreshContact(id) {
      try {
        const { data } = await api.post(`/contacts/${id}/refresh`)
        const idx = this.contacts.findIndex(c => c.id === id)
        if (idx !== -1) this.contacts[idx] = data.contact
        if (this.selectedContact?.id === id) this.selectedContact = data.contact
        return data.contact
      } catch (err) {
        this.error = 'Failed to refresh contact'
        return null
      }
    }
  }
})
