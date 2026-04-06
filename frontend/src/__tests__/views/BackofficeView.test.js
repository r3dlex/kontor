import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

const { mockBackOfficeGet, mockCalendarRefreshBriefing, mockSetViewContext } = vi.hoisted(() => ({
  mockBackOfficeGet: vi.fn(),
  mockCalendarRefreshBriefing: vi.fn(),
  mockSetViewContext: vi.fn()
}))

vi.mock('@/api', () => ({
  backOfficeApi: {
    get: mockBackOfficeGet
  },
  calendarApi: {
    refreshBriefing: mockCalendarRefreshBriefing
  }
}))

vi.mock('@/stores/chat', () => ({
  useChatStore: () => ({
    setViewContext: mockSetViewContext
  })
}))

import BackofficeView from '@/views/BackOfficeView.vue'

function mountView() {
  return mount(BackofficeView, {
    global: {
      plugins: [createPinia()]
    }
  })
}

const sampleEvents = [
  {
    id: 1,
    title: 'Standup',
    start_time: '2026-04-06T09:00:00Z',
    end_time: '2026-04-06T09:30:00Z',
    attendees: ['alice@example.com', 'bob@example.com'],
    location: 'Zoom',
    briefing_markdown: null
  },
  {
    id: 2,
    title: 'Sprint Review',
    start_time: '2026-04-06T14:00:00Z',
    end_time: '2026-04-06T15:00:00Z',
    attendees: [],
    location: null,
    briefing_markdown: '# Agenda\n\nReview sprint goals'
  }
]

describe('BackofficeView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('loading state', () => {
    it('shows loading message while fetching', () => {
      mockBackOfficeGet.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.loading').exists()).toBe(true)
      expect(wrapper.find('.loading').text()).toBe('Loading briefings...')
    })

    it('does not show meetings while loading', () => {
      mockBackOfficeGet.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.meetings').exists()).toBe(false)
    })
  })

  describe('empty state', () => {
    it('shows "No meetings today." when events array is empty', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: [] } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.empty').text()).toBe('No meetings today.')
    })

    it('does not show loading after data loads', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: [] } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.loading').exists()).toBe(false)
    })
  })

  describe('meetings list', () => {
    it('renders a meeting card for each event', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.findAll('.meeting-card')).toHaveLength(2)
    })

    it('renders event titles', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      expect(cards[0].find('h3').text()).toBe('Standup')
      expect(cards[1].find('h3').text()).toBe('Sprint Review')
    })

    it('renders attendee badges', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      const attendees = cards[0].findAll('.attendee')
      expect(attendees).toHaveLength(2)
      expect(attendees[0].text()).toBe('alice@example.com')
      expect(attendees[1].text()).toBe('bob@example.com')
    })

    it('renders location when present', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      expect(cards[0].find('.location').exists()).toBe(true)
    })

    it('does not render location when null', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      expect(cards[1].find('.location').exists()).toBe(false)
    })
  })

  describe('briefing section', () => {
    it('shows "Generate Briefing" button when no briefing_markdown', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      expect(cards[0].find('.no-briefing button').text()).toBe('Generate Briefing')
    })

    it('shows briefing content when briefing_markdown is set', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      expect(cards[1].find('.briefing-content').exists()).toBe(true)
    })

    it('shows Refresh button when briefing_markdown is set', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      expect(cards[1].find('.refresh-btn').exists()).toBe(true)
      expect(cards[1].find('.refresh-btn').text()).toBe('Refresh')
    })

    it('calls calendarApi.refreshBriefing when Generate Briefing is clicked', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      mockCalendarRefreshBriefing.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      await cards[0].find('.no-briefing button').trigger('click')
      expect(mockCalendarRefreshBriefing).toHaveBeenCalledWith(1)
    })

    it('shows "Generating..." while refreshing', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      mockCalendarRefreshBriefing.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      await cards[0].find('.no-briefing button').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(cards[0].find('.no-briefing button').text()).toBe('Generating...')
    })

    it('disables Generate Briefing button while refreshing', async () => {
      mockBackOfficeGet.mockResolvedValueOnce({ data: { events: sampleEvents } })
      mockCalendarRefreshBriefing.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.meeting-card')
      await cards[0].find('.no-briefing button').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(cards[0].find('.no-briefing button').attributes('disabled')).toBeDefined()
    })
  })

  describe('onMounted', () => {
    it('calls backOfficeApi.get on mount', () => {
      mockBackOfficeGet.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockBackOfficeGet).toHaveBeenCalledTimes(1)
    })

    it('sets view context on mount', () => {
      mockBackOfficeGet.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockSetViewContext).toHaveBeenCalledWith({
        view: 'back_office',
        available_actions: ['refresh_briefing']
      })
    })

    it('hides loading and shows empty on API error', async () => {
      mockBackOfficeGet.mockRejectedValueOnce(new Error('Network error'))
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.loading').exists()).toBe(false)
      expect(wrapper.find('.empty').text()).toBe('No meetings today.')
    })
  })
})
