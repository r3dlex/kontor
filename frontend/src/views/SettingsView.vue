<template>
  <div class="settings-view">
    <h2>Settings</h2>

    <section class="section">
      <h3>Connected Mailboxes</h3>
      <div v-for="mb in mailboxes" :key="mb.id" class="mailbox-row">
        <div class="mailbox-info">
          <span class="provider-badge" :class="mb.provider">{{ mb.provider }}</span>
          <span class="mailbox-label">{{ mb.label || mb.id }}</span>
        </div>
        <div class="mailbox-config">
          <label>
            Polling
            <select v-model="mb.polling_interval_seconds" @change="saveMailbox(mb)">
              <option :value="30">30s</option>
              <option :value="60">1 min</option>
              <option :value="300">5 min</option>
            </select>
          </label>
          <label>
            Task cutoff
            <select v-model="mb.task_age_cutoff_months" @change="saveMailbox(mb)">
              <option :value="1">1 month</option>
              <option :value="3">3 months</option>
              <option :value="6">6 months</option>
              <option :value="12">1 year</option>
            </select>
          </label>
        </div>
      </div>

      <div class="add-mailbox">
        <a href="/api/v1/auth/google/redirect" class="btn-add">+ Add Google</a>
        <a href="/api/v1/auth/microsoft/redirect" class="btn-add">+ Add Microsoft</a>
      </div>
    </section>

    <section class="section">
      <h3>AI Thresholds</h3>
      <label class="field">
        Auto-confirm threshold (high)
        <input type="number" v-model.number="prefs.auto_confirm_high" min="0" max="1" step="0.05" />
        <span class="hint">Tasks above this confidence auto-confirm and sync to Asana</span>
      </label>
      <label class="field">
        Surface threshold (low)
        <input type="number" v-model.number="prefs.auto_confirm_low" min="0" max="1" step="0.05" />
        <span class="hint">Tasks above this threshold appear in Review section</span>
      </label>
      <button @click="savePrefs" class="btn-save">Save</button>
    </section>

    <section class="section">
      <h3>Appearance</h3>
      <label class="field">
        Font size
        <input type="number" v-model.number="prefs.font_size" min="12" max="20" />
      </label>
    </section>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '@/api'

const mailboxes = ref([])
const prefs = ref({
  auto_confirm_high: 0.85,
  auto_confirm_low: 0.5,
  font_size: 14
})

onMounted(async () => {
  const { data } = await api.get('/mailboxes')
  mailboxes.value = data.mailboxes
})

async function saveMailbox(mb) {
  await api.patch(`/mailboxes/${mb.id}`, {
    mailbox: {
      polling_interval_seconds: mb.polling_interval_seconds,
      task_age_cutoff_months: mb.task_age_cutoff_months
    }
  })
}

async function savePrefs() {
  await api.put('/config', { config: prefs.value })
}
</script>

<style scoped>
.settings-view { padding: 24px; max-width: 640px; }

h2 { font-size: 20px; font-weight: 600; color: #fff; margin-bottom: 28px; }

.section {
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 16px;
}

h3 { font-size: 14px; font-weight: 600; color: #e8e8e8; margin-bottom: 16px; }

.mailbox-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 0;
  border-bottom: 1px solid #1f1f1f;
}

.mailbox-info { display: flex; align-items: center; gap: 10px; }

.provider-badge {
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 4px;
  text-transform: uppercase;
}

.provider-badge.google { background: #1a3a1a; color: #86efac; }
.provider-badge.microsoft { background: #1a2a3a; color: #7dd3fc; }

.mailbox-label { font-size: 13px; color: #ccc; }

.mailbox-config { display: flex; gap: 16px; }

.mailbox-config label {
  font-size: 12px;
  color: #666;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.mailbox-config select {
  background: #1f1f1f;
  border: 1px solid #333;
  border-radius: 4px;
  color: #ccc;
  padding: 4px 8px;
  font-size: 12px;
}

.add-mailbox { display: flex; gap: 8px; margin-top: 12px; }

.btn-add {
  font-size: 12px;
  color: #7dd3fc;
  text-decoration: none;
  border: 1px solid #2d4a6a;
  border-radius: 6px;
  padding: 6px 12px;
  background: #1a2a3a;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 13px;
  color: #888;
  margin-bottom: 14px;
}

.field input {
  background: #1f1f1f;
  border: 1px solid #333;
  border-radius: 6px;
  color: #e8e8e8;
  padding: 8px 12px;
  font-size: 14px;
  width: 120px;
}

.hint { font-size: 11px; color: #555; }

.btn-save {
  background: #1a3a5c;
  color: #7dd3fc;
  border: 1px solid #2d5a8c;
  border-radius: 6px;
  padding: 8px 20px;
  font-size: 13px;
  cursor: pointer;
}
</style>
