<template>
  <div class="chat-panel">
    <div class="chat-header">
      <span>Assistant</span>
    </div>

    <div class="messages" ref="messagesEl">
      <div
        v-for="(msg, i) in chat.messages"
        :key="i"
        :class="['message', msg.role]"
      >
        <div class="message-content" v-html="formatMessage(msg.content)" />
      </div>
      <div v-if="chat.isTyping" class="message assistant">
        <div class="typing-indicator">
          <span /><span /><span />
        </div>
      </div>
    </div>

    <div class="chat-input">
      <textarea
        v-model="input"
        placeholder="Ask anything..."
        @keydown.enter.exact.prevent="send"
        rows="1"
        ref="inputEl"
      />
      <button @click="send" :disabled="!input.trim() || chat.isTyping">Send</button>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, nextTick } from 'vue'
import { useChatStore } from '@/stores/chat'

const chat = useChatStore()
const input = ref('')
const messagesEl = ref(null)
const inputEl = ref(null)

async function send() {
  const text = input.value.trim()
  if (!text) return
  input.value = ''
  await chat.sendMessage(text)
}

function formatMessage(content) {
  // Basic markdown-like formatting
  return content
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.*?)\*/g, '<em>$1</em>')
    .replace(/`(.*?)`/g, '<code>$1</code>')
    .replace(/\n/g, '<br>')
}

watch(() => chat.messages.length, async () => {
  await nextTick()
  if (messagesEl.value) {
    messagesEl.value.scrollTop = messagesEl.value.scrollHeight
  }
})
</script>

<style scoped>
.chat-panel {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.chat-header {
  padding: 14px 16px;
  border-bottom: 1px solid #2a2a2a;
  font-size: 13px;
  font-weight: 600;
  color: #888;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.messages {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.message {
  max-width: 90%;
  padding: 10px 14px;
  border-radius: 12px;
  font-size: 14px;
  line-height: 1.5;
}

.message.user {
  background: #1a3a5c;
  align-self: flex-end;
  color: #e8e8e8;
}

.message.assistant {
  background: #1f1f1f;
  align-self: flex-start;
  color: #d0d0d0;
}

.typing-indicator {
  display: flex;
  gap: 4px;
  align-items: center;
  padding: 2px 0;
}

.typing-indicator span {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #555;
  animation: bounce 1.2s infinite;
}

.typing-indicator span:nth-child(2) { animation-delay: 0.2s; }
.typing-indicator span:nth-child(3) { animation-delay: 0.4s; }

@keyframes bounce {
  0%, 60%, 100% { transform: translateY(0); }
  30% { transform: translateY(-4px); }
}

.chat-input {
  border-top: 1px solid #2a2a2a;
  padding: 12px 16px;
  display: flex;
  gap: 8px;
  align-items: flex-end;
}

.chat-input textarea {
  flex: 1;
  background: #1a1a1a;
  border: 1px solid #333;
  border-radius: 8px;
  color: #e8e8e8;
  padding: 10px 12px;
  font-size: 14px;
  resize: none;
  font-family: inherit;
  line-height: 1.4;
  max-height: 120px;
  overflow-y: auto;
}

.chat-input textarea:focus {
  outline: none;
  border-color: #444;
}

.chat-input button {
  background: #1a3a5c;
  color: #fff;
  border: none;
  border-radius: 8px;
  padding: 10px 16px;
  font-size: 13px;
  cursor: pointer;
  white-space: nowrap;
}

.chat-input button:disabled {
  opacity: 0.4;
  cursor: default;
}
</style>
