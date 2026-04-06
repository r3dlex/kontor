import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

const { mockEmailsGet, mockSetViewContext } = vi.hoisted(() => ({
  mockEmailsGet: vi.fn(),
  mockSetViewContext: vi.fn()
}))

vi.mock('@/api', () => ({
  emailsApi: {
    get: mockEmailsGet
  }
}))

vi.mock('@/stores/chat', () => ({
  useChatStore: () => ({
    setViewContext: mockSetViewContext
  })
}))

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: '99' } })
}))

import EmailView from '@/views/EmailView.vue'

function mountView() {
  return mount(EmailView, {
    global: {
      plugins: [createPinia()],
      mocks: {
        $router: { back: vi.fn() }
      }
    }
  })
}

const sampleEmail = {
  id: 99,
  subject: 'Hello World',
  sender: 'alice@example.com',
  body: 'This is the email body.',
  received_at: '2024-01-15T10:30:00Z',
  thread_id: 'thread-1'
}

const sampleThread = {
  id: 'thread-1',
  markdown_content: '# Summary\n\nThis is a summary.'
}

describe('EmailView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('loading state', () => {
    it('shows loading message while fetching', () => {
      mockEmailsGet.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.loading').exists()).toBe(true)
      expect(wrapper.find('.loading').text()).toBe('Loading...')
    })

    it('does not show email view while loading', () => {
      mockEmailsGet.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.email-view').exists()).toBe(false)
    })
  })

  describe('email data', () => {
    it('renders email subject as heading', async () => {
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('h2').text()).toBe('Hello World')
    })

    it('renders sender name', async () => {
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.from').text()).toContain('alice@example.com')
    })

    it('renders email body in pre element', async () => {
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.body-text').text()).toBe('This is the email body.')
    })

    it('renders formatted date', async () => {
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.date').text()).toBeTruthy()
    })
  })

  describe('thread summary', () => {
    it('does not render thread summary when no thread', async () => {
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.thread-summary').exists()).toBe(false)
    })

    it('renders thread summary when thread is present', async () => {
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail, thread: sampleThread } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.thread-summary').exists()).toBe(true)
    })

    it('renders thread summary section label', async () => {
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail, thread: sampleThread } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.thread-summary .section-label').text()).toBe('Thread Summary')
    })
  })

  describe('renderMarkdown', () => {
    it('renders markdown content as HTML', async () => {
      const thread = { markdown_content: '# Title\n\n**bold** text' }
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail, thread } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const content = wrapper.find('.summary-content').html()
      expect(content).toContain('<h3>')
      expect(content).toContain('<strong>')
    })

    it('renders list items', async () => {
      const thread = { markdown_content: '- item one\n- item two' }
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail, thread } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.summary-content').html()).toContain('<li>')
    })

    it('returns empty string for null markdown', async () => {
      const thread = { markdown_content: null }
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail, thread } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.summary-content').html()).not.toContain('<h3>')
    })
  })

  describe('back button', () => {
    it('renders back button', async () => {
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.back').exists()).toBe(true)
    })
  })

  describe('onMounted', () => {
    it('calls emailsApi.get with route param id', () => {
      mockEmailsGet.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockEmailsGet).toHaveBeenCalledWith('99')
    })

    it('sets view context after loading', async () => {
      mockEmailsGet.mockResolvedValueOnce({ data: { email: sampleEmail } })
      mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(mockSetViewContext).toHaveBeenCalledWith({
        view: 'email',
        active_email_id: '99',
        active_thread_id: 'thread-1',
        available_actions: ['reply', 'draft', 'create_task', 'schedule_send']
      })
    })
  })
})
