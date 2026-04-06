import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { ref } from 'vue'

// --- API mock (CalendarView uses calendarApi directly) ---
const { mockCalendarToday, mockSetViewContext } = vi.hoisted(() => ({
  mockCalendarToday: vi.fn(),
  mockSetViewContext: vi.fn()
}))

vi.mock('@/api', () => ({
  calendarApi: {
    today: mockCalendarToday
  }
}))

vi.mock('@/stores/chat', () => ({
  useChatStore: () => ({
    setViewContext: mockSetViewContext
  })
}))

import CalendarView from '@/views/CalendarView.vue'

function mountView() {
  return mount(CalendarView, {
    global: {
      plugins: [createPinia()]
    }
  })
}

describe('CalendarView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('loading state', () => {
    it('shows loading message while fetching', () => {
      // Never resolve so it stays in loading state
      mockCalendarToday.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.loading').exists()).toBe(true)
      expect(wrapper.find('.loading').text()).toBe('Loading...')
    })

    it('does not show events while loading', () => {
      mockCalendarToday.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.events').exists()).toBe(false)
    })
  })

  describe('empty state', () => {
    it('shows "No events today." when events array is empty', async () => {
      mockCalendarToday.mockResolvedValueOnce({ data: { events: [] } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.empty').text()).toBe('No events today.')
    })

    it('does not show loading after data loads', async () => {
      mockCalendarToday.mockResolvedValueOnce({ data: { events: [] } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.loading').exists()).toBe(false)
    })
  })

  describe('events list', () => {
    const sampleEvents = [
      {
        id: 1,
        title: 'Standup',
        start_time: '2026-04-06T09:00:00Z',
        end_time: '2026-04-06T09:30:00Z',
        provider: 'google',
        attendees: ['alice@example.com', 'bob@example.com'],
        location: null
      },
      {
        id: 2,
        title: 'Sprint Review',
        start_time: '2026-04-06T14:00:00Z',
        end_time: '2026-04-06T15:00:00Z',
        provider: 'microsoft',
        attendees: [],
        location: 'Conference Room A'
      }
    ]

    it('renders an event card for each event', async () => {
      mockCalendarToday.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.findAll('.event-card')).toHaveLength(2)
    })

    it('renders event titles', async () => {
      mockCalendarToday.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.event-card')
      expect(cards[0].find('h3').text()).toBe('Standup')
      expect(cards[1].find('h3').text()).toBe('Sprint Review')
    })

    it('renders provider badges', async () => {
      mockCalendarToday.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const badges = wrapper.findAll('.provider-badge')
      expect(badges[0].text()).toBe('google')
      expect(badges[1].text()).toBe('microsoft')
    })

    it('renders location when present', async () => {
      mockCalendarToday.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.event-card')
      expect(cards[1].find('.location').text()).toBe('Conference Room A')
    })

    it('does not render location element when location is null', async () => {
      mockCalendarToday.mockResolvedValueOnce({ data: { events: sampleEvents } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.event-card')
      expect(cards[0].find('.location').exists()).toBe(false)
    })
  })

  describe('onMounted', () => {
    it('calls calendarApi.today on mount', () => {
      mockCalendarToday.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockCalendarToday).toHaveBeenCalledTimes(1)
    })

    it('sets view context on mount', () => {
      mockCalendarToday.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockSetViewContext).toHaveBeenCalledWith({
        view: 'calendar',
        available_actions: ['create_event', 'get_briefing']
      })
    })
  })

  describe('error state', () => {
    it('hides loading and shows empty state on API error', async () => {
      mockCalendarToday.mockRejectedValueOnce(new Error('Network error'))
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.loading').exists()).toBe(false)
      expect(wrapper.find('.empty').text()).toBe('No events today.')
    })
  })
})
