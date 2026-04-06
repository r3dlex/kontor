import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { reactive } from 'vue'

// --- Store mock ---
// Use reactive() so Vue auto-unwraps properties in templates (Pinia does this internally)
const chatStore = reactive({
  messages: [],
  isTyping: false,
  sendMessage: vi.fn()
})

vi.mock('@/stores/chat', () => ({
  useChatStore: () => chatStore
}))

import ChatPanel from '@/components/ChatPanel.vue'

function mountPanel() {
  return mount(ChatPanel, {
    global: {
      plugins: [createPinia()]
    },
    attachTo: document.body
  })
}

describe('ChatPanel', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    chatStore.messages = []
    chatStore.isTyping = false
    chatStore.sendMessage.mockClear()
  })

  describe('message rendering', () => {
    it('renders no messages when messages array is empty', () => {
      const wrapper = mountPanel()
      expect(wrapper.findAll('.message')).toHaveLength(0)
    })

    it('renders a user message with "user" class', () => {
      chatStore.messages = [{ role: 'user', content: 'Hello!' }]
      const wrapper = mountPanel()
      const msg = wrapper.find('.message.user')
      expect(msg.exists()).toBe(true)
    })

    it('renders an assistant message with "assistant" class', () => {
      chatStore.messages = [{ role: 'assistant', content: 'Hi there!' }]
      const wrapper = mountPanel()
      const msg = wrapper.find('.message.assistant')
      expect(msg.exists()).toBe(true)
    })

    it('renders message content inside message-content div', () => {
      chatStore.messages = [{ role: 'user', content: 'Test message' }]
      const wrapper = mountPanel()
      expect(wrapper.find('.message-content').html()).toContain('Test message')
    })

    it('renders multiple messages in order', () => {
      chatStore.messages = [
        { role: 'user', content: 'First' },
        { role: 'assistant', content: 'Second' },
        { role: 'user', content: 'Third' }
      ]
      const wrapper = mountPanel()
      const messages = wrapper.findAll('.message')
      expect(messages).toHaveLength(3)
      expect(messages[0].classes()).toContain('user')
      expect(messages[1].classes()).toContain('assistant')
      expect(messages[2].classes()).toContain('user')
    })

    it('escapes HTML in message content to prevent XSS', () => {
      chatStore.messages = [{ role: 'user', content: '<script>alert("xss")</script>' }]
      const wrapper = mountPanel()
      expect(wrapper.find('.message-content').html()).not.toContain('<script>')
      expect(wrapper.find('.message-content').html()).toContain('&lt;script&gt;')
    })

    it('converts **bold** markdown to <strong> tags', () => {
      chatStore.messages = [{ role: 'assistant', content: '**bold text**' }]
      const wrapper = mountPanel()
      expect(wrapper.find('.message-content').html()).toContain('<strong>bold text</strong>')
    })

    it('converts *italic* markdown to <em> tags', () => {
      chatStore.messages = [{ role: 'assistant', content: '*italic text*' }]
      const wrapper = mountPanel()
      expect(wrapper.find('.message-content').html()).toContain('<em>italic text</em>')
    })

    it('converts `code` markdown to <code> tags', () => {
      chatStore.messages = [{ role: 'assistant', content: '`some code`' }]
      const wrapper = mountPanel()
      expect(wrapper.find('.message-content').html()).toContain('<code>some code</code>')
    })
  })

  describe('typing indicator', () => {
    it('is not shown when isTyping is false', () => {
      chatStore.isTyping = false
      const wrapper = mountPanel()
      expect(wrapper.find('.typing-indicator').exists()).toBe(false)
    })

    it('is shown when isTyping is true', () => {
      chatStore.isTyping = true
      const wrapper = mountPanel()
      expect(wrapper.find('.typing-indicator').exists()).toBe(true)
    })

    it('is rendered inside an assistant message bubble', () => {
      chatStore.isTyping = true
      const wrapper = mountPanel()
      expect(wrapper.find('.message.assistant .typing-indicator').exists()).toBe(true)
    })
  })

  describe('Send button disabled state', () => {
    it('is disabled when the input is empty', () => {
      const wrapper = mountPanel()
      expect(wrapper.find('button').attributes('disabled')).toBeDefined()
    })

    it('is disabled when the input contains only whitespace', async () => {
      const wrapper = mountPanel()
      await wrapper.find('textarea').setValue('   ')
      expect(wrapper.find('button').attributes('disabled')).toBeDefined()
    })

    it('is enabled when the input has non-whitespace text', async () => {
      const wrapper = mountPanel()
      await wrapper.find('textarea').setValue('Hello')
      expect(wrapper.find('button').attributes('disabled')).toBeUndefined()
    })

    it('is disabled when isTyping is true even with text in the input', async () => {
      chatStore.isTyping = true
      const wrapper = mountPanel()
      await wrapper.find('textarea').setValue('Some text')
      expect(wrapper.find('button').attributes('disabled')).toBeDefined()
    })
  })

  describe('Send button click', () => {
    it('calls chat.sendMessage with the trimmed input text', async () => {
      const wrapper = mountPanel()
      await wrapper.find('textarea').setValue('  Hello world  ')
      await wrapper.find('button').trigger('click')
      expect(chatStore.sendMessage).toHaveBeenCalledWith('Hello world')
    })

    it('clears the input after sending', async () => {
      const wrapper = mountPanel()
      await wrapper.find('textarea').setValue('Hello')
      await wrapper.find('button').trigger('click')
      expect(wrapper.find('textarea').element.value).toBe('')
    })

    it('does not call sendMessage when input is empty', async () => {
      const wrapper = mountPanel()
      await wrapper.find('button').trigger('click')
      expect(chatStore.sendMessage).not.toHaveBeenCalled()
    })
  })

  describe('Enter key behaviour', () => {
    it('calls chat.sendMessage when Enter is pressed in the textarea', async () => {
      const wrapper = mountPanel()
      await wrapper.find('textarea').setValue('Enter test')
      await wrapper.find('textarea').trigger('keydown.enter')
      expect(chatStore.sendMessage).toHaveBeenCalledWith('Enter test')
    })

    it('clears the textarea after Enter key send', async () => {
      const wrapper = mountPanel()
      await wrapper.find('textarea').setValue('Enter test')
      await wrapper.find('textarea').trigger('keydown.enter')
      expect(wrapper.find('textarea').element.value).toBe('')
    })

    it('does not send when textarea is empty and Enter is pressed', async () => {
      const wrapper = mountPanel()
      await wrapper.find('textarea').trigger('keydown.enter')
      expect(chatStore.sendMessage).not.toHaveBeenCalled()
    })
  })

  describe('layout', () => {
    it('renders the "Assistant" header label', () => {
      const wrapper = mountPanel()
      expect(wrapper.find('.chat-header').text()).toBe('Assistant')
    })

    it('renders the textarea with placeholder text', () => {
      const wrapper = mountPanel()
      expect(wrapper.find('textarea').attributes('placeholder')).toBe('Ask anything...')
    })
  })
})
