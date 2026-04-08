import { defineStore } from 'pinia'
import api from '@/api'

export const useMailboxesStore = defineStore('mailboxes', {
  state: () => ({
    mailboxes: [],
    selectedMailboxId: null,
    loading: false,
    error: null
  }),

  getters: {
    selectedMailbox: (state) => state.mailboxes.find(m => m.id === state.selectedMailboxId),
    hasMailboxes: (state) => state.mailboxes.length > 0
  },

  actions: {
    async fetchMailboxes() {
      this.loading = true
      this.error = null
      try {
        const { data } = await api.get('/mailboxes')
        this.mailboxes = data.mailboxes || []
        if (!this.selectedMailboxId && this.mailboxes.length > 0) {
          this.selectedMailboxId = this.mailboxes[0].id
        }
      } catch (err) {
        this.error = err.response?.data?.error || 'Failed to fetch mailboxes'
      } finally {
        this.loading = false
      }
    },

    selectMailbox(id) {
      this.selectedMailboxId = id
    },

    async createMailbox(attrs) {
      try {
        const { data } = await api.post('/mailboxes', attrs)
        this.mailboxes.push(data.mailbox)
        return { success: true, mailbox: data.mailbox }
      } catch (err) {
        this.error = err.response?.data?.error || 'Failed to create mailbox'
        return { success: false, error: this.error }
      }
    },

    async updateMailbox(id, attrs) {
      try {
        const { data } = await api.patch(`/mailboxes/${id}`, attrs)
        const idx = this.mailboxes.findIndex(m => m.id === id)
        if (idx !== -1) this.mailboxes[idx] = data.mailbox
        return { success: true, mailbox: data.mailbox }
      } catch (err) {
        this.error = err.response?.data?.error || 'Failed to update mailbox'
        return { success: false, error: this.error }
      }
    }
  }
})
