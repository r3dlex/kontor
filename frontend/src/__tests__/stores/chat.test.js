import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

// Build a reusable mock channel factory
function makeMockChannel() {
  return {
    on: vi.fn(),
    join: vi.fn().mockReturnValue({ receive: vi.fn().mockReturnThis() }),
    leave: vi.fn(),
    push: vi.fn()
  }
}

// Build a reusable mock socket factory
function makeMockSocket(channel) {
  return {
    connect: vi.fn(),
    disconnect: vi.fn(),
    channel: vi.fn().mockReturnValue(channel)
  }
}

// Capture the Socket constructor so tests can control instances
let mockSocketInstance = null
let mockChannelInstance = null

vi.mock('phoenix', () => {
  return {
    Socket: vi.fn().mockImplementation(() => {
      mockChannelInstance = makeMockChannel()
      mockSocketInstance = makeMockSocket(mockChannelInstance)
      return mockSocketInstance
    })
  }
})

vi.mock('@/api', () => ({
  default: { defaults: { headers: { common: {} } } }
}))

vi.mock('@/router', () => ({
  default: { push: vi.fn() }
}))

import { Socket } from 'phoenix'
import { useChatStore } from '@/stores/chat'
import { useAuthStore } from '@/stores/auth'

describe('chat store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockSocketInstance = null
    mockChannelInstance = null
    vi.clearAllMocks()
  })

  describe('setViewContext', () => {
    it('stores the provided context object', () => {
      const store = useChatStore()
      const ctx = { view: 'task_list', available_actions: ['create_task'] }
      store.setViewContext(ctx)
      expect(store.viewContext).toEqual(ctx)
    })

    it('overwrites previously set context', () => {
      const store = useChatStore()
      store.setViewContext({ view: 'task_list' })
      store.setViewContext({ view: 'back_office' })
      expect(store.viewContext).toEqual({ view: 'back_office' })
    })
  })

  describe('sendMessage', () => {
    it('does nothing when channel is not connected', async () => {
      const store = useChatStore()
      await store.sendMessage('hello')
      expect(store.messages).toHaveLength(0)
    })

    it('pushes a user message to the messages array immediately', async () => {
      const store = useChatStore()
      // Connect to create the channel
      const authStore = useAuthStore()
      authStore.token = 'tok'
      authStore.user = { id: 42 }
      store.connect()

      await store.sendMessage('Hello there')

      expect(store.messages).toHaveLength(1)
      expect(store.messages[0]).toMatchObject({
        role: 'user',
        content: 'Hello there'
      })
    })

    it('sets isTyping to true after sending', async () => {
      const store = useChatStore()
      const authStore = useAuthStore()
      authStore.token = 'tok'
      authStore.user = { id: 42 }
      store.connect()

      await store.sendMessage('ping')
      expect(store.isTyping).toBe(true)
    })

    it('includes a timestamp on the user message', async () => {
      const store = useChatStore()
      const authStore = useAuthStore()
      authStore.token = 'tok'
      authStore.user = { id: 42 }
      store.connect()

      await store.sendMessage('hi')
      expect(store.messages[0].timestamp).toBeDefined()
      expect(typeof store.messages[0].timestamp).toBe('string')
    })

    it('pushes the message payload to the channel', async () => {
      const store = useChatStore()
      const authStore = useAuthStore()
      authStore.token = 'tok'
      authStore.user = { id: 42 }
      store.connect()

      store.setViewContext({ view: 'tasks' })
      await store.sendMessage('Do something')

      expect(mockChannelInstance.push).toHaveBeenCalledWith('user_message', {
        content: 'Do something',
        view_context: { view: 'tasks' }
      })
    })
  })

  describe('connect', () => {
    it('creates a Socket with the auth token', () => {
      // Socket imported at top
      const store = useChatStore()
      const authStore = useAuthStore()
      authStore.token = 'user-token'
      authStore.user = { id: 10 }
      store.connect()
      expect(Socket).toHaveBeenCalledWith('/socket', { params: { token: 'user-token' } })
    })

    it('does not create a second socket if already connected', () => {
      // Socket imported at top
      const store = useChatStore()
      const authStore = useAuthStore()
      authStore.token = 'tok'
      authStore.user = { id: 10 }
      store.connect()
      store.connect()
      expect(Socket).toHaveBeenCalledTimes(1)
    })

    it('registers a new_message handler on the channel', () => {
      const store = useChatStore()
      const authStore = useAuthStore()
      authStore.token = 'tok'
      authStore.user = { id: 10 }
      store.connect()
      const onCalls = mockChannelInstance.on.mock.calls.map(c => c[0])
      expect(onCalls).toContain('new_message')
    })

    it('registers a typing handler on the channel', () => {
      const store = useChatStore()
      const authStore = useAuthStore()
      authStore.token = 'tok'
      authStore.user = { id: 10 }
      store.connect()
      const onCalls = mockChannelInstance.on.mock.calls.map(c => c[0])
      expect(onCalls).toContain('typing')
    })
  })

  describe('clearMessages', () => {
    it('empties the messages array', () => {
      const store = useChatStore()
      store.messages.push({ role: 'user', content: 'hi' })
      store.clearMessages()
      expect(store.messages).toHaveLength(0)
    })
  })

  describe('disconnect', () => {
    it('leaves the channel and disconnects the socket', () => {
      const store = useChatStore()
      const authStore = useAuthStore()
      authStore.token = 'tok'
      authStore.user = { id: 10 }
      store.connect()
      store.disconnect()
      expect(mockChannelInstance.leave).toHaveBeenCalled()
      expect(mockSocketInstance.disconnect).toHaveBeenCalled()
    })
  })
})
