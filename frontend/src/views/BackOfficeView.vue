<template>
  <div class="backoffice">
    <div class="header">
      <h2>Back Office</h2>
      <span class="date">{{ today }}</span>
    </div>

    <div v-if="loading" class="loading">Loading briefings...</div>

    <div v-else-if="events.length === 0" class="empty">
      No meetings today.
    </div>

    <div v-else class="meetings">
      <div v-for="event in events" :key="event.id" class="meeting-card">
        <div class="meeting-time">
          {{ formatTime(event.start_time) }} – {{ formatTime(event.end_time) }}
        </div>

        <div class="meeting-details">
          <h3>{{ event.title }}</h3>
          <div class="attendees">
            <span v-for="a in event.attendees" :key="a" class="attendee">{{ a }}</span>
          </div>
          <div v-if="event.location" class="location">📍 {{ event.location }}</div>
        </div>

        <div class="briefing-section">
          <div v-if="event.briefing_markdown" class="briefing-content" v-html="renderMarkdown(event.briefing_markdown)" />
          <div v-else class="no-briefing">
            <button @click="refreshBriefing(event.id)" :disabled="refreshing[event.id]">
              {{ refreshing[event.id] ? 'Generating...' : 'Generate Briefing' }}
            </button>
          </div>

          <button
            v-if="event.briefing_markdown"
            @click="refreshBriefing(event.id)"
            class="refresh-btn"
            :disabled="refreshing[event.id]"
          >
            {{ refreshing[event.id] ? 'Refreshing...' : 'Refresh' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { backOfficeApi, calendarApi } from '@/api'
import { useChatStore } from '@/stores/chat'

const events = ref([])
const loading = ref(true)
const refreshing = ref({})
const chat = useChatStore()

const today = new Date().toLocaleDateString('en-US', {
  weekday: 'long', month: 'long', day: 'numeric'
})

onMounted(async () => {
  chat.setViewContext({ view: 'back_office', available_actions: ['refresh_briefing'] })
  try {
    const { data } = await backOfficeApi.get()
    events.value = data.events
  } catch {
    // leave events empty; empty state renders
  } finally {
    loading.value = false
  }
})

async function refreshBriefing(eventId) {
  refreshing.value[eventId] = true
  try {
    const { data } = await calendarApi.refreshBriefing(eventId)
    const event = events.value.find(e => e.id === eventId)
    if (event) event.briefing_markdown = data.briefing_markdown
  } finally {
    refreshing.value[eventId] = false
  }
}

function formatTime(dt) {
  return new Date(dt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
}

function renderMarkdown(md) {
  return md
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/^# (.+)$/gm, '<h3>$1</h3>')
    .replace(/^## (.+)$/gm, '<h4>$1</h4>')
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/^- (.+)$/gm, '<li>$1</li>')
    .replace(/\n\n/g, '<br>')
}
</script>

<style scoped>
.backoffice { padding: 24px; }

.header {
  display: flex;
  align-items: baseline;
  gap: 16px;
  margin-bottom: 24px;
}

h2 { font-size: 20px; font-weight: 600; color: #fff; }
.date { color: #555; font-size: 14px; }

.meetings { display: flex; flex-direction: column; gap: 16px; }

.meeting-card {
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 12px;
  padding: 20px;
  display: grid;
  grid-template-columns: 120px 1fr;
  grid-template-rows: auto auto;
  gap: 16px;
}

.meeting-time {
  font-size: 13px;
  color: #3b82f6;
  font-weight: 600;
  padding-top: 2px;
}

.meeting-details { grid-column: 2; }

h3 { font-size: 16px; font-weight: 600; color: #fff; margin-bottom: 8px; }

.attendees { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }

.attendee {
  font-size: 11px;
  background: #1f1f1f;
  border: 1px solid #333;
  border-radius: 4px;
  padding: 2px 8px;
  color: #888;
}

.location { font-size: 12px; color: #666; }

.briefing-section {
  grid-column: 1 / -1;
  border-top: 1px solid #2a2a2a;
  padding-top: 16px;
}

.briefing-content {
  font-size: 13px;
  color: #c0c0c0;
  line-height: 1.6;
}

.briefing-content :deep(h3) { font-size: 14px; font-weight: 600; color: #e8e8e8; margin: 12px 0 6px; }
.briefing-content :deep(h4) { font-size: 13px; font-weight: 600; color: #ccc; margin: 10px 0 4px; }
.briefing-content :deep(li) { margin-left: 16px; margin-bottom: 4px; }

.no-briefing { display: flex; justify-content: center; padding: 16px; }

button {
  background: #1a2a3a;
  color: #7dd3fc;
  border: 1px solid #2d4a6a;
  border-radius: 6px;
  padding: 8px 16px;
  font-size: 13px;
  cursor: pointer;
}

button:disabled { opacity: 0.5; cursor: default; }

.refresh-btn {
  margin-top: 12px;
  background: transparent;
  color: #555;
  border-color: #333;
  font-size: 12px;
  padding: 4px 12px;
}

.loading, .empty { color: #555; font-size: 14px; padding: 40px; text-align: center; }
</style>
