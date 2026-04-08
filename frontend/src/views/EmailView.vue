<template>
  <div class="email-view" v-if="email">
    <div class="header">
      <button class="back" @click="$router.back()">← Back</button>
    </div>

    <div class="email-meta">
      <h2>{{ email.subject }}</h2>
      <div class="from">From: <strong>{{ email.sender }}</strong></div>
      <div class="date">{{ formatDate(email.received_at) }}</div>
    </div>

    <div class="thread-summary" v-if="thread">
      <div class="section-label">Thread Summary</div>
      <div class="summary-content" v-html="renderMarkdown(thread.markdown_content)" />
    </div>

    <div class="email-body">
      <div class="section-label">Email</div>
      <pre v-if="email.body" class="body-text">{{ email.body }}</pre>
      <p v-else class="body-null">Body not stored — email content was used for AI processing but not retained.</p>
    </div>
  </div>
  <div v-else-if="loading" class="loading">Loading...</div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { emailsApi } from '@/api'
import { useChatStore } from '@/stores/chat'

const route = useRoute()
const email = ref(null)
const thread = ref(null)
const loading = ref(true)
const chat = useChatStore()

onMounted(async () => {
  try {
    const { data } = await emailsApi.get(route.params.id)
    email.value = data.email
    if (data.thread) thread.value = data.thread

    chat.setViewContext({
      view: 'email',
      active_email_id: route.params.id,
      active_thread_id: email.value?.thread_id,
      available_actions: ['reply', 'draft', 'create_task', 'schedule_send']
    })
  } finally {
    loading.value = false
  }
})

function formatDate(dt) {
  return new Date(dt).toLocaleString('en-US', {
    month: 'short', day: 'numeric', year: 'numeric',
    hour: 'numeric', minute: '2-digit'
  })
}

function renderMarkdown(md) {
  if (!md) return ''
  return md
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/^# (.+)$/gm, '<h3>$1</h3>')
    .replace(/^## (.+)$/gm, '<h4>$1</h4>')
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/^- (.+)$/gm, '<li>$1</li>')
    .replace(/\n\n/g, '<br><br>')
}
</script>

<style scoped>
.email-view { padding: 24px; max-width: 800px; }

.header { margin-bottom: 20px; }
.back { background: transparent; border: none; color: #666; font-size: 14px; cursor: pointer; }
.back:hover { color: #fff; }

.email-meta { margin-bottom: 24px; padding-bottom: 20px; border-bottom: 1px solid #2a2a2a; }
h2 { font-size: 18px; font-weight: 600; color: #fff; margin-bottom: 8px; }
.from { font-size: 13px; color: #888; margin-bottom: 4px; }
.from strong { color: #ccc; }
.date { font-size: 12px; color: #555; }

.thread-summary {
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 10px;
  padding: 16px;
  margin-bottom: 20px;
}

.section-label {
  font-size: 11px;
  color: #555;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 10px;
}

.summary-content { font-size: 13px; color: #c0c0c0; line-height: 1.6; }
.summary-content :deep(h3) { font-size: 13px; font-weight: 600; color: #e0e0e0; margin: 10px 0 4px; }
.summary-content :deep(h4) { font-size: 12px; font-weight: 600; color: #ccc; margin: 8px 0 4px; }
.summary-content :deep(li) { margin: 3px 0 3px 14px; }

.email-body { background: #141414; border: 1px solid #2a2a2a; border-radius: 10px; padding: 16px; }

.body-text {
  font-size: 13px;
  color: #c0c0c0;
  white-space: pre-wrap;
  word-break: break-word;
  font-family: inherit;
  line-height: 1.6;
}

.loading { color: #555; font-size: 14px; padding: 40px; text-align: center; }

.body-null { font-size: 13px; color: #555; font-style: italic; margin: 0; }
</style>
