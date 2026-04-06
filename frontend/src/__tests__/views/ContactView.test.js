import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

const { mockContactsGet, mockContactsRefresh, mockSetViewContext } = vi.hoisted(() => ({
  mockContactsGet: vi.fn(),
  mockContactsRefresh: vi.fn(),
  mockSetViewContext: vi.fn()
}))

vi.mock('@/api', () => ({
  contactsApi: {
    get: mockContactsGet,
    refresh: mockContactsRefresh
  }
}))

vi.mock('@/stores/chat', () => ({
  useChatStore: () => ({
    setViewContext: mockSetViewContext
  })
}))

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: '42' } })
}))

import ContactView from '@/views/ContactView.vue'

function mountView() {
  return mount(ContactView, {
    global: {
      plugins: [createPinia()],
      mocks: {
        $router: { back: vi.fn() }
      }
    }
  })
}

const sampleContact = {
  id: 42,
  display_name: 'Alice Smith',
  email_address: 'alice@example.com',
  organization: 'Acme Corp',
  role: 'Engineer',
  profile_markdown: null
}

describe('ContactView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('loading state', () => {
    it('shows loading message while fetching', () => {
      mockContactsGet.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.loading').exists()).toBe(true)
      expect(wrapper.find('.loading').text()).toBe('Loading...')
    })

    it('does not show contact hero while loading', () => {
      mockContactsGet.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.contact-hero').exists()).toBe(false)
    })
  })

  describe('contact data', () => {
    it('renders contact display_name as heading', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('h2').text()).toBe('Alice Smith')
    })

    it('falls back to email_address when display_name is missing', async () => {
      const contact = { ...sampleContact, display_name: null }
      mockContactsGet.mockResolvedValueOnce({ data: { contact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('h2').text()).toBe('alice@example.com')
    })

    it('renders email address', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.email').text()).toBe('alice@example.com')
    })

    it('renders organization when present', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.meta').text()).toContain('Acme Corp')
    })

    it('renders role when present', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.meta').text()).toContain('Engineer')
    })

    it('renders avatar initials from display_name', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.avatar').text()).toBe('AL')
    })

    it('renders avatar initials from email when display_name is missing', async () => {
      const contact = { ...sampleContact, display_name: null }
      mockContactsGet.mockResolvedValueOnce({ data: { contact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.avatar').text()).toBe('AL')
    })
  })

  describe('profile section', () => {
    it('shows "No profile generated yet." when profile_markdown is null', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.no-profile').text()).toBe('No profile generated yet.')
    })

    it('shows profile content when profile_markdown is set', async () => {
      const contact = { ...sampleContact, profile_markdown: '# Profile\n\nSome content' }
      mockContactsGet.mockResolvedValueOnce({ data: { contact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.profile-content').exists()).toBe(true)
    })

    it('does not show no-profile div when profile_markdown is set', async () => {
      const contact = { ...sampleContact, profile_markdown: '# Profile' }
      mockContactsGet.mockResolvedValueOnce({ data: { contact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.no-profile').exists()).toBe(false)
    })
  })

  describe('refresh button', () => {
    it('renders "Refresh Profile" button', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.refresh-btn').text()).toBe('Refresh Profile')
    })

    it('calls contactsApi.refresh with contact id when clicked', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      mockContactsRefresh.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.find('.refresh-btn').trigger('click')
      expect(mockContactsRefresh).toHaveBeenCalledWith('42')
    })

    it('shows "Refreshing..." while refresh is in progress', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      mockContactsRefresh.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.find('.refresh-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.refresh-btn').text()).toBe('Refreshing...')
    })

    it('disables refresh button while refreshing', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      mockContactsRefresh.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.find('.refresh-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.refresh-btn').attributes('disabled')).toBeDefined()
    })

    it('updates contact after successful refresh', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      const updatedContact = { ...sampleContact, display_name: 'Alice Updated' }
      mockContactsRefresh.mockResolvedValueOnce({ data: { contact: updatedContact } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.find('.refresh-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('h2').text()).toBe('Alice Updated')
    })
  })

  describe('onMounted', () => {
    it('calls contactsApi.get with route param id on mount', () => {
      mockContactsGet.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockContactsGet).toHaveBeenCalledWith('42')
    })

    it('sets view context after loading', async () => {
      mockContactsGet.mockResolvedValueOnce({ data: { contact: sampleContact } })
      mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(mockSetViewContext).toHaveBeenCalledWith({
        view: 'contact',
        active_contact_id: '42',
        available_actions: ['refresh_profile']
      })
    })
  })
})
