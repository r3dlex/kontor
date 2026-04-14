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
            <Select v-model="mb.polling_interval_seconds" @change="saveMailbox(mb)" :options="pollingOptions" optionLabel="label" optionValue="value" />
          </label>
          <label>
            Task cutoff
            <Select v-model="mb.task_age_cutoff_months" @change="saveMailbox(mb)" :options="cutoffOptions" optionLabel="label" optionValue="value" />
          </label>
          <label>
            Folder model
            <span v-if="mb.folder_model_locked_at" class="folder-model-locked">
              <span class="locked-badge">Locked</span>
            </span>
            <Select
              v-else
              v-model="mb.folder_model"
              @change="onFolderModelChange(mb)"
              :options="folderModelOptions"
              optionLabel="label"
              optionValue="value"
            />
            <span class="hint">Bootstrap: {{ mb.folder_bootstrap_count ?? 0 }} / 50 emails</span>
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
        <InputNumber v-model="prefs.auto_confirm_high" :min="0" :max="1" :step="0.05" :maxFractionDigits="2" />
        <span class="hint">Tasks above this confidence auto-confirm and sync to Asana</span>
      </label>
      <label class="field">
        Surface threshold (low)
        <InputNumber v-model="prefs.auto_confirm_low" :min="0" :max="1" :step="0.05" :maxFractionDigits="2" />
        <span class="hint">Tasks above this threshold appear in Review section</span>
      </label>
      <Button @click="savePrefs" label="Save" class="btn-save" />
    </section>

    <section class="section">
      <h3>Appearance</h3>
      <label class="field">
        Font size
        <InputNumber v-model="prefs.font_size" :min="12" :max="20" />
      </label>
    </section>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '@/api'
import Select from 'primevue/select'
import InputNumber from 'primevue/inputnumber'
import Button from 'primevue/button'

const mailboxes = ref([])
const prefs = ref({
  auto_confirm_high: 0.85,
  auto_confirm_low: 0.5,
  font_size: 14
})

const pollingOptions = [
  { label: '30s', value: 30 },
  { label: '1 min', value: 60 },
  { label: '5 min', value: 300 }
]

const cutoffOptions = [
  { label: '1 month', value: 1 },
  { label: '3 months', value: 3 },
  { label: '6 months', value: 6 },
  { label: '1 year', value: 12 }
]

const folderModelOptions = [
  { label: 'Structural / PARA', value: 'structural_category' },
  { label: 'Action-Based', value: 'action_based' },
  { label: 'Decision (4 D\'s)', value: 'decision' }
]

onMounted(async () => {
  const { data } = await api.get('/mailboxes')
  mailboxes.value = data.mailboxes
})

async function saveMailbox(mb) {
  await api.patch(`/mailboxes/${mb.id}`, {
    mailbox: {
      polling_interval_seconds: mb.polling_interval_seconds,
      task_age_cutoff_months: mb.task_age_cutoff_months,
      folder_model: mb.folder_model
    }
  })
}

function onFolderModelChange(mb) {
  const confirmed = window.confirm(
    'This organizational model cannot be changed once email processing begins. Are you sure?'
  )
  if (confirmed) {
    saveMailbox(mb)
  } else {
    api.get('/mailboxes').then(({ data }) => {
      mailboxes.value = data.mailboxes
    })
  }
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

h3 { font-size: 14px; font-weight: 600; color: #e8e0e0; margin-bottom: 16px; }

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

.mailbox-config :deep(.p-select),
.mailbox-config :deep(.p-selectlabel) {
  background: #1f1f1f;
  border: 1px solid #333;
  border-radius: 4px;
  color: #ccc;
  font-size: 12px;
}

.folder-model-locked {
  display: flex;
  align-items: center;
  gap: 4px;
}

.locked-badge {
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 4px;
  background: #2a1a1a;
  color: #f87171;
  border: 1px solid #4a2020;
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

.field :deep(.p-inputnumber-input) {
  background: #1f1f1f;
  border: 1px solid #333;
  border-radius: 6px;
  color: #e8e8e8;
  padding: 8px 12px;
  font-size: 14px;
  width: 120px;
}

.hint { font-size: 11px; color: #555; }
</style>
