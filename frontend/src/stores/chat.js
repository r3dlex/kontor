import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { Socket } from 'phoenix'
import { useAuthStore } from './auth'

export const useChatStore = defineStore('chat', () => {
  const messages = ref([])
  const isTyping = ref(false)
  const socket = ref(null)
  const channel = ref(null)
  const viewContext = ref({})

  const authStore = useAuthStore()

  function connect() {
    if (socket.value) return

    socket.value = new Socket('/socket', {
      params: { token: authStore.token }
    })
    socket.value.connect()

    const userId = authStore.user?.id
    channel.value = socket.value.channel(`chat:${userId}`, {})

    channel.value.on('new_message', (msg) => {
      messages.value.push(msg)
      isTyping.value = false
    })

    channel.value.on('typing', () => {
      isTyping.value = true
    })

    channel.value.join()
      .receive('ok', () => console.log('Chat channel joined'))
      .receive('error', (e) => console.error('Chat join error', e))
  }

  function disconnect() {
    if (channel.value) channel.value.leave()
    if (socket.value) socket.value.disconnect()
    socket.value = null
    channel.value = null
  }

  async function sendMessage(content) {
    if (!channel.value) return

    const userMsg = { role: 'user', content, timestamp: new Date().toISOString() }
    messages.value.push(userMsg)
    isTyping.value = true

    channel.value.push('user_message', {
      content,
      view_context: viewContext.value
    })
  }

  function setViewContext(ctx) {
    viewContext.value = ctx
  }

  function clearMessages() {
    messages.value = []
  }

  return {
    messages,
    isTyping,
    viewContext,
    connect,
    disconnect,
    sendMessage,
    setViewContext,
    clearMessages
  }
})
