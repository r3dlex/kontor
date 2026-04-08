<template>
  <div class="mailbox-settings">
    <h3 class="settings-title">Mailbox Settings</h3>

    <div class="setting-row">
      <label class="setting-label" for="copy-emails-toggle">
        <span class="label-text">Store full email bodies</span>
        <span class="label-hint">When disabled, email bodies are used for AI processing then discarded to save storage.</span>
      </label>
      <input
        id="copy-emails-toggle"
        type="checkbox"
        class="toggle"
        v-model="copyEmails"
      />
    </div>

    <div class="actions">
      <button class="save-btn" :disabled="saving" @click="save">
        {{ saving ? 'Saving...' : 'Save' }}
      </button>
      <span v-if="saveError" class="save-error">{{ saveError }}</span>
      <span v-if="saveSuccess" class="save-success">Saved.</span>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useMailboxesStore } from '@/stores/mailboxes'

const props = defineProps({
  mailbox: {
    type: Object,
    required: true
  }
})

const store = useMailboxesStore()

const copyEmails = ref(props.mailbox.copy_emails ?? false)
const saving = ref(false)
const saveError = ref(null)
const saveSuccess = ref(false)

watch(() => props.mailbox, (mb) => {
  copyEmails.value = mb.copy_emails ?? false
})

async function save() {
  saving.value = true
  saveError.value = null
  saveSuccess.value = false

  const result = await store.updateMailbox(props.mailbox.id, { copy_emails: copyEmails.value })

  saving.value = false
  if (result.success) {
    saveSuccess.value = true
    setTimeout(() => { saveSuccess.value = false }, 2000)
  } else {
    saveError.value = result.error
  }
}
</script>

<style scoped>
.mailbox-settings {
  padding: 20px;
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 10px;
}

.settings-title {
  font-size: 14px;
  font-weight: 600;
  color: #e0e0e0;
  margin-bottom: 16px;
}

.setting-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 16px;
}

.setting-label {
  display: flex;
  flex-direction: column;
  gap: 4px;
  cursor: pointer;
}

.label-text {
  font-size: 13px;
  color: #c0c0c0;
}

.label-hint {
  font-size: 11px;
  color: #555;
  line-height: 1.5;
}

.toggle {
  margin-top: 2px;
  cursor: pointer;
}

.actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.save-btn {
  padding: 6px 16px;
  background: #2a2a2a;
  border: 1px solid #444;
  border-radius: 6px;
  color: #e0e0e0;
  font-size: 13px;
  cursor: pointer;
}

.save-btn:hover:not(:disabled) {
  background: #333;
}

.save-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.save-error {
  font-size: 12px;
  color: #e05555;
}

.save-success {
  font-size: 12px;
  color: #55b855;
}
</style>
