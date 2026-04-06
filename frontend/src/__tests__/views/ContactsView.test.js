import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// --- API mock (ContactsView uses contactsApi directly) ---
const { mockContactsList, mockContactsGraph, mockSetViewContext } = vi.hoisted(() => ({
  mockContactsList: vi.fn(),
  mockContactsGraph: vi.fn(),
  mockSetViewContext: vi.fn()
}))

vi.mock('@/api', () => ({
  contactsApi: {
    list: mockContactsList,
    graph: mockContactsGraph
  }
}))

vi.mock('@/stores/chat', () => ({
  useChatStore: () => ({
    setViewContext: mockSetViewContext
  })
}))

// Mock vis-network to avoid DOM issues in test environment
vi.mock('vis-network', () => ({
  Network: vi.fn(),
  DataSet: vi.fn(() => ({}))
}))

vi.mock('vis-network/styles/vis-network.min.css', () => ({}))

import ContactsView from '@/views/ContactsView.vue'

const sampleContacts = [
  { id: 1, display_name: 'Alice Smith', email_address: 'alice@example.com', organization: 'Acme', importance_weight: 0.9 },
  { id: 2, display_name: 'Bob Jones', email_address: 'bob@example.com', organization: null, importance_weight: 0.5 },
  { id: 3, email_address: 'charlie@example.com', organization: 'Initech', importance_weight: 0.2 },
  { id: 4, display_name: 'Dana Null', email_address: 'dana@example.com', organization: null, importance_weight: null }
]

function mountView() {
  return mount(ContactsView, {
    global: {
      plugins: [createPinia()],
      stubs: {
        RouterLink: true
      },
      mocks: {
        $router: { push: vi.fn() }
      }
    }
  })
}

describe('ContactsView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('onMounted', () => {
    it('calls contactsApi.list on mount', () => {
      mockContactsList.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockContactsList).toHaveBeenCalledTimes(1)
    })

    it('sets view context on mount', () => {
      mockContactsList.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockSetViewContext).toHaveBeenCalledWith({
        view: 'contacts',
        available_actions: ['view_contact', 'refresh_profile']
      })
    })
  })

  describe('contacts list', () => {
    it('renders a contact card for each contact', async () => {
      mockContactsList.mockResolvedValueOnce({ data: { contacts: sampleContacts } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.findAll('.contact-card')).toHaveLength(4)
    })

    it('renders contact display_name when available', async () => {
      mockContactsList.mockResolvedValueOnce({ data: { contacts: sampleContacts } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.contact-card')
      expect(cards[0].find('.contact-name').text()).toBe('Alice Smith')
    })

    it('falls back to email_address when display_name is missing', async () => {
      mockContactsList.mockResolvedValueOnce({ data: { contacts: sampleContacts } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.contact-card')
      expect(cards[2].find('.contact-name').text()).toBe('charlie@example.com')
    })

    it('renders contact email address', async () => {
      mockContactsList.mockResolvedValueOnce({ data: { contacts: sampleContacts } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.contact-card')
      expect(cards[0].find('.contact-email').text()).toBe('alice@example.com')
    })

    it('renders organization when present', async () => {
      mockContactsList.mockResolvedValueOnce({ data: { contacts: sampleContacts } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.contact-card')
      expect(cards[0].find('.contact-org').text()).toBe('Acme')
    })

    it('does not render organization element when null', async () => {
      mockContactsList.mockResolvedValueOnce({ data: { contacts: sampleContacts } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.contact-card')
      expect(cards[1].find('.contact-org').exists()).toBe(false)
    })

    it('renders initials avatar from display_name', async () => {
      mockContactsList.mockResolvedValueOnce({ data: { contacts: sampleContacts } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.contact-card')
      expect(cards[0].find('.contact-avatar').text()).toBe('AL')
    })
  })

  describe('loading state', () => {
    it('renders no contact cards while data is loading', () => {
      mockContactsList.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.findAll('.contact-card')).toHaveLength(0)
    })
  })

  describe('view toggle', () => {
    it('starts with list view active', () => {
      mockContactsList.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.contact-list').exists()).toBe(true)
    })

    it('renders list and graph toggle buttons', () => {
      mockContactsList.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      const buttons = wrapper.findAll('.view-toggle button')
      expect(buttons).toHaveLength(2)
      expect(buttons[0].text()).toBe('List')
      expect(buttons[1].text()).toBe('Graph')
    })

    it('switches to graph view when Graph button is clicked', async () => {
      mockContactsList.mockResolvedValueOnce({ data: { contacts: sampleContacts } })
      mockContactsGraph.mockResolvedValueOnce({
        data: {
          nodes: [
            { id: 1, label: 'Alice', title: 'alice@example.com', value: 0.9 },
            { id: 2, label: 'Bob', title: 'bob@example.com', value: null }
          ],
          edges: [{ from: 1, to: 2, value: 1, title: 'connected' }]
        }
      })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const graphBtn = wrapper.findAll('.view-toggle button')[1]
      await graphBtn.trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(mockContactsGraph).toHaveBeenCalledTimes(1)
    })
  })

  describe('ringStyle', () => {
    it('renders contact avatar element for contacts with importance_weight', async () => {
      mockContactsList.mockResolvedValueOnce({ data: { contacts: sampleContacts } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      // ringStyle is called during render; just verify the avatar element is present
      expect(wrapper.findAll('.contact-card')[0].find('.contact-avatar').exists()).toBe(true)
    })
  })
})
