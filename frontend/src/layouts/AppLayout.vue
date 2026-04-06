<template>
  <div class="app-layout">
    <nav class="sidebar">
      <div class="logo">
  <svg width="116" height="28" viewBox="0 0 320 60" fill="none" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="lg-sidebar" x1="0" y1="0" x2="60" y2="60" gradientUnits="userSpaceOnUse">
        <stop offset="0%" stop-color="#60a5fa"/>
        <stop offset="100%" stop-color="#a78bfa"/>
      </linearGradient>
    </defs>
    <text x="0" y="46" font-family="'Arial Black','Helvetica Neue',Arial,sans-serif" font-size="46" font-weight="900" fill="url(#lg-sidebar)">K</text>
    <text x="36" y="46" font-family="'Arial Black','Helvetica Neue',Arial,sans-serif" font-size="46" font-weight="900" fill="white">ontor</text>
  </svg>
</div>
      <ul class="nav-links">
        <li><RouterLink to="/tasks">Tasks</RouterLink></li>
        <li><RouterLink to="/backoffice">Back Office</RouterLink></li>
        <li><RouterLink to="/calendar">Calendar</RouterLink></li>
        <li><RouterLink to="/contacts">Contacts</RouterLink></li>
        <li><RouterLink to="/skills">Skills</RouterLink></li>
        <li><RouterLink to="/settings">Settings</RouterLink></li>
      </ul>
      <ImportProgress v-if="importProgress" :progress="importProgress" />
    </nav>

    <main class="main-content">
      <RouterView />
    </main>

    <aside class="chat-panel">
      <ChatPanel />
    </aside>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { RouterLink, RouterView } from 'vue-router'
import { Socket } from 'phoenix'
import { useAuthStore } from '@/stores/auth'
import { useChatStore } from '@/stores/chat'
import { useTaskStore } from '@/stores/tasks'
import ChatPanel from '@/components/ChatPanel.vue'
import ImportProgress from '@/components/ImportProgress.vue'

const auth = useAuthStore()
const chat = useChatStore()
const taskStore = useTaskStore()
const importProgress = ref(null)

let notifSocket = null
let notifChannel = null

onMounted(() => {
  chat.connect()

  // Notifications channel
  notifSocket = new Socket('/socket', { params: { token: auth.token } })
  notifSocket.connect()
  notifChannel = notifSocket.channel(`notifications:${auth.user?.id}`, {})

  notifChannel.on('import_progress', ({ current, total }) => {
    importProgress.value = { current, total }
    if (current >= total) setTimeout(() => { importProgress.value = null }, 3000)
  })

  notifChannel.join()

  // Tasks channel
  const tasksChannel = notifSocket.channel(`tasks:${auth.user?.id}`, {})
  tasksChannel.on('task_created', ({ task }) => taskStore.handleRealtimeUpdate(task))
  tasksChannel.on('task_updated', ({ task }) => taskStore.handleRealtimeUpdate(task))
  tasksChannel.join()
})

onUnmounted(() => {
  chat.disconnect()
  if (notifChannel) notifChannel.leave()
  if (notifSocket) notifSocket.disconnect()
})
</script>

<style scoped>
.app-layout {
  display: grid;
  grid-template-columns: 200px 1fr 360px;
  height: 100vh;
  overflow: hidden;
}

.sidebar {
  background: #141414;
  border-right: 1px solid #2a2a2a;
  padding: 20px 16px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.logo {
  padding: 4px 0;
}

.nav-links {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.nav-links a {
  display: block;
  padding: 8px 12px;
  border-radius: 6px;
  color: #888;
  text-decoration: none;
  font-size: 14px;
  transition: all 0.15s;
}

.nav-links a:hover, .nav-links a.router-link-active {
  background: #1f1f1f;
  color: #fff;
}

.main-content {
  overflow-y: auto;
  background: #0f0f0f;
}

.chat-panel {
  border-left: 1px solid #2a2a2a;
  background: #111;
  display: flex;
  flex-direction: column;
}
</style>
