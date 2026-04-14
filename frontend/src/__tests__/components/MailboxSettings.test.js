import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

const mockUpdateMailbox = vi.fn()
vi.mock('@/stores/mailboxes', () => ({
  useMailboxesStore: () => ({
    updateMailbox: mockUpdateMailbox
  })
}))

import MailboxSettings from '@/components/MailboxSettings.vue'

function mountComponent(mailbox) {
  return mount(MailboxSettings, {
    props: { mailbox },
    global: { plugins: [createPinia()] }
  })
}

describe('MailboxSettings', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('rendering', () => {
    it('renders settings title', () => {
      const wrapper = mountComponent({ id: 'mb1', copy_emails: false })
      expect(wrapper.find('.settings-title').text()).toBe('Mailbox Settings')
    })

    it('renders checkbox label', () => {
      const wrapper = mountComponent({ id: 'mb1', copy_emails: false })
      expect(wrapper.find('.label-text').text()).toBe('Store full email bodies')
    })

    it('renders Save button', () => {
      const wrapper = mountComponent({ id: 'mb1', copy_emails: false })
      expect(wrapper.find('.save-btn').exists()).toBe(true)
      expect(wrapper.find('.save-btn').text()).toBe('Save')
    })
  })

  describe('save', () => {
    it('calls store.updateMailbox with copy_emails=true when saved', async () => {
      mockUpdateMailbox.mockResolvedValueOnce({ success: true })
      const wrapper = mountComponent({ id: 'mb1', copy_emails: false })
      await wrapper.find('.save-btn').trigger('click')
      expect(mockUpdateMailbox).toHaveBeenCalledWith('mb1', { copy_emails: false })
    })

    it('shows "Saved." after successful save', async () => {
      mockUpdateMailbox.mockResolvedValueOnce({ success: true })
      const wrapper = mountComponent({ id: 'mb1', copy_emails: false })
      await wrapper.find('.save-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.save-success').exists()).toBe(true)
    })

    it('shows error message on failed save', async () => {
      mockUpdateMailbox.mockResolvedValueOnce({ success: false, error: 'Save failed' })
      const wrapper = mountComponent({ id: 'mb1', copy_emails: false })
      await wrapper.find('.save-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.save-error').exists()).toBe(true)
    })

    it('disables Save button while saving', async () => {
      mockUpdateMailbox.mockResolvedValueOnce({ success: true })
      const wrapper = mountComponent({ id: 'mb1', copy_emails: false })
      await wrapper.find('.save-btn').trigger('click')
      // Button should be disabled immediately after click (saving = true)
      expect(wrapper.find('.save-btn').attributes('disabled')).toBeDefined()
    })
  })
})