<template>
  <div class="calendar-view">
    <div class="header">
      <h2>Calendar</h2>
      <span class="date">{{ today }}</span>
    </div>

    <div v-if="loading" class="loading">Loading...</div>
    <div v-else-if="events.length === 0" class="empty">No events today.</div>

    <div v-else class="events">
      <div v-for="event in events" :key="event.id" class="event-card">
        <div class="event-time">
          <span class="start">{{ formatTime(event.start_time) }}</span>
          <span class="duration">{{ duration(event) }}</span>
        </div>
        <div class="event-body">
          <h3>{{ event.title }}</h3>
          <div v-if="event.location" class="location">{{ event.location }}</div>
          <div class="attendees">{{ event.attendees?.slice(0, 3).join(', ') }}<span v-if="event.attendees?.length > 3"> +{{ event.attendees.length - 3 }}</span></div>
        </div>
        <div class="event-provider">
          <Tag :value="event.provider" :severity="event.provider === 'google' ? 'success' : 'info'" class="provider-badge" />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { calendarApi } from '@/api'
import { useChatStore } from '@/stores/chat'
import Tag from 'primevue/tag'

const events = ref([])
const loading = ref(true)
const chat = useChatStore()

const today = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })

onMounted(async () => {
  chat.setViewContext({ view: 'calendar', available_actions: ['create_event', 'get_briefing'] })
  try {
    const { data } = await calendarApi.today()
    events.value = data.events
  } catch {
    // leave events empty; empty state renders
  } finally {
    loading.value = false
  }
})

function formatTime(dt) {
  return new Date(dt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
}

function duration(event) {
  const mins = Math.round((new Date(event.end_time) - new Date(event.start_time)) / 60000)
  return mins >= 60 ? `${Math.floor(mins / 60)}h${mins % 60 ? ' ' + (mins % 60) + 'm' : ''}` : `${mins}m`
}
</script>

<style scoped>
.calendar-view { padding: 24px; }

.header { display: flex; align-items: baseline; gap: 16px; margin-bottom: 24px; }
h2 { font-size: 20px; font-weight: 600; color: #fff; }
.date { color: #555; font-size: 14px; }

.events { display: flex; flex-direction: column; gap: 8px; }

.event-card {
  display: flex;
  align-items: flex-start;
  gap: 16px;
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 10px;
  padding: 16px;
}

.event-time { min-width: 80px; }
.start { display: block; font-size: 14px; font-weight: 600; color: #3b82f6; }
.duration { font-size: 11px; color: #555; }

.event-body { flex: 1; }
h3 { font-size: 15px; font-weight: 500; color: #e8e8e8; margin-bottom: 4px; }
.location { font-size: 12px; color: #666; margin-bottom: 4px; }
.attendees { font-size: 12px; color: #555; }

.event-provider { display: flex; align-items: center; }

.loading, .empty { color: #555; font-size: 14px; padding: 40px; text-align: center; }
</style>
