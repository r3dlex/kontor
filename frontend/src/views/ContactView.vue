<template>
  <div class="contact-view" v-if="contact">
    <div class="header">
      <Button label="← Back" text severity="secondary" @click="$router.back()" class="back" />
      <Button @click="refresh" :disabled="refreshing" :label="refreshing ? 'Refreshing...' : 'Refresh Profile'" size="small" class="refresh-btn" />
    </div>

    <div class="contact-hero">
      <div class="avatar">{{ initials(contact) }}</div>
      <div class="contact-info">
        <h2>{{ contact.display_name || contact.email_address }}</h2>
        <div class="email">{{ contact.email_address }}</div>
        <div class="meta">
          <span v-if="contact.organization">{{ contact.organization }}</span>
          <span v-if="contact.role">· {{ contact.role }}</span>
        </div>
      </div>
    </div>

    <div class="profile-content" v-if="contact.profile_markdown" v-html="renderMarkdown(contact.profile_markdown)" />
    <div v-else class="no-profile">No profile generated yet.</div>
  </div>
  <div v-else-if="loading" class="loading">Loading...</div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { contactsApi } from '@/api'
import { useChatStore } from '@/stores/chat'
import Button from 'primevue/button'

const route = useRoute()
const contact = ref(null)
const loading = ref(true)
const refreshing = ref(false)
const chat = useChatStore()

onMounted(async () => {
  const { data } = await contactsApi.get(route.params.id)
  contact.value = data.contact
  loading.value = false
  chat.setViewContext({ view: 'contact', active_contact_id: route.params.id, available_actions: ['refresh_profile'] })
})

async function refresh() {
  refreshing.value = true
  try {
    const { data } = await contactsApi.refresh(route.params.id)
    contact.value = data.contact
  } finally {
    refreshing.value = false
  }
}

function initials(c) {
  return (c.display_name || c.email_address).slice(0, 2).toUpperCase()
}

function renderMarkdown(md) {
  return md
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/^# (.+)$/gm, '<h2>$1</h2>')
    .replace(/^## (.+)$/gm, '<h3>$1</h3>')
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/^- (.+)$/gm, '<li>$1</li>')
    .replace(/\n\n/g, '<p>')
}
</script>

<style scoped>
.contact-view { padding: 24px; }

.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }

.back { background: transparent; border: none; color: #666; font-size: 14px; cursor: pointer; }

.contact-hero {
  display: flex;
  align-items: center;
  gap: 20px;
  margin-bottom: 32px;
  padding-bottom: 24px;
  border-bottom: 1px solid #2a2a2a;
}

.avatar {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: #1a3a5c;
  color: #7dd3fc;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
  font-weight: 600;
}

h2 { font-size: 22px; font-weight: 600; color: #fff; margin-bottom: 4px; }
.email { font-size: 14px; color: #666; margin-bottom: 4px; }
.meta { font-size: 13px; color: #555; }

.profile-content { font-size: 14px; color: #c0c0c0; line-height: 1.7; }
.profile-content :deep(h2) { font-size: 16px; font-weight: 600; color: #fff; margin: 20px 0 8px; }
.profile-content :deep(h3) { font-size: 14px; font-weight: 600; color: #e0e0e0; margin: 14px 0 6px; }
.profile-content :deep(strong) { color: #e8e8e8; }
.profile-content :deep(li) { margin: 4px 0 4px 16px; }

.no-profile, .loading { color: #555; font-size: 14px; padding: 40px; text-align: center; }
</style>
