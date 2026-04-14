<template>
  <div class="skills-view">
    <div class="header">
      <h2>Skills</h2>
    </div>

    <div v-if="loading" class="loading">Loading...</div>

    <div v-else class="skills-layout">
      <!-- Left panel: skill list -->
      <div class="skills-list">
        <div
          v-for="skill in skills"
          :key="skill.id"
          class="skill-card"
          :class="{ selected: selectedSkill && selectedSkill.id === skill.id }"
          @click="selectSkill(skill)"
        >
          <div class="skill-header">
            <div class="skill-name">{{ skill.name }}</div>
            <div class="skill-badges">
              <span v-if="skill.locked" class="badge locked">Locked</span>
              <span v-if="!skill.active" class="badge inactive">Inactive</span>
              <span class="badge namespace">{{ skill.namespace }}</span>
            </div>
          </div>
          <div class="skill-meta">
            <span>v{{ skill.version }}</span>
            <span>·</span>
            <span>{{ skill.author }}</span>
          </div>
          <div class="skill-actions" @click.stop>
            <Button
              @click="toggleActive(skill)"
              :label="skill.active ? 'Deactivate' : 'Activate'"
              size="small"
              :severity="skill.active ? 'secondary' : 'success'"
              text
              :class="skill.active ? 'btn-deactivate' : 'btn-activate'"
            />
          </div>
        </div>
      </div>

      <!-- Right panel: editor -->
      <div v-if="selectedSkill" class="skill-editor">
        <div class="editor-header">
          <div class="editor-title">
            <span class="editor-skill-name">{{ selectedSkill.name }}</span>
            <div class="editor-badges">
              <span v-if="selectedSkill.locked" class="badge locked">Locked</span>
              <span v-if="!selectedSkill.active" class="badge inactive">Inactive</span>
              <span class="badge namespace">{{ selectedSkill.namespace }}</span>
            </div>
          </div>
          <div class="editor-meta">v{{ selectedSkill.version }} · {{ selectedSkill.author }}</div>
        </div>

        <div class="editor-tabs">
          <button
            class="tab-btn"
            :class="{ active: activeTab === 'content' }"
            @click="activeTab = 'content'"
          >Content</button>
          <button
            class="tab-btn"
            :class="{ active: activeTab === 'versions' }"
            @click="switchToVersions"
          >Versions</button>
        </div>

        <!-- Content tab -->
        <div v-if="activeTab === 'content'" class="tab-pane">
          <div v-if="loadingContent" class="loading">Loading content...</div>
          <template v-else>
            <Textarea
              class="content-textarea"
              rows="20"
              v-model="editableContent"
              autoResize
            />
            <div class="editor-actions">
              <Button class="btn-save" :disabled="saving" @click="saveContent" :label="saving ? 'Saving...' : 'Save'" />
              <span v-if="saveError" class="save-error">{{ saveError }}</span>
              <span v-if="saveSuccess" class="save-success">Saved.</span>
            </div>
          </template>
        </div>

        <!-- Versions tab -->
        <div v-if="activeTab === 'versions'" class="tab-pane">
          <div v-if="loadingVersions" class="loading">Loading versions...</div>
          <div v-else-if="versions.length === 0" class="empty">No version history yet.</div>
          <div v-else class="versions-layout">
            <div class="versions-list">
              <div
                v-for="v in versions"
                :key="v.id"
                class="version-item"
                :class="{ selected: selectedVersion && selectedVersion.id === v.id }"
                @click="selectVersion(v)"
              >
                <div class="version-number">v{{ v.version }}</div>
                <div class="version-meta">
                  <span>{{ v.author }}</span>
                  <span>{{ formatDate(v.updated_at || v.inserted_at) }}</span>
                </div>
              </div>
            </div>
            <div v-if="selectedVersion" class="version-preview">
              <Textarea
                class="content-textarea readonly"
                rows="16"
                readonly
                :modelValue="selectedVersion.content"
                autoResize
              />
              <div class="editor-actions">
                <Button
                  class="btn-save"
                  :disabled="reverting"
                  @click="revertToVersion(selectedVersion)"
                  :label="reverting ? 'Reverting...' : 'Revert to this version'"
                />
                <span v-if="revertError" class="save-error">{{ revertError }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div v-else class="editor-empty">
        <span>Select a skill to edit</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { skillsApi } from '@/api'
import { useChatStore } from '@/stores/chat'
import Button from 'primevue/button'
import Textarea from 'primevue/textarea'

const skills = ref([])
const loading = ref(true)
const chat = useChatStore()

const selectedSkill = ref(null)
const activeTab = ref('content')

const editableContent = ref('')
const loadingContent = ref(false)
const saving = ref(false)
const saveError = ref('')
const saveSuccess = ref(false)

const versions = ref([])
const loadingVersions = ref(false)
const selectedVersion = ref(null)
const reverting = ref(false)
const revertError = ref('')

onMounted(async () => {
  chat.setViewContext({ view: 'skill_editor', available_actions: ['list_skills', 'trigger_skill'] })
  try {
    const { data } = await skillsApi.list()
    skills.value = data.skills
  } finally {
    loading.value = false
  }
})

async function toggleActive(skill) {
  const { data } = await skillsApi.update(skill.id, { active: !skill.active })
  const idx = skills.value.findIndex(s => s.id === skill.id)
  if (idx !== -1) {
    skills.value[idx] = data.skill
    if (selectedSkill.value && selectedSkill.value.id === skill.id) {
      selectedSkill.value = data.skill
    }
  }
}

async function selectSkill(skill) {
  selectedSkill.value = skill
  activeTab.value = 'content'
  saveError.value = ''
  saveSuccess.value = false
  versions.value = []
  selectedVersion.value = null

  loadingContent.value = true
  try {
    const { data } = await skillsApi.get(skill.id)
    editableContent.value = data.skill.content || ''
  } finally {
    loadingContent.value = false
  }
}

async function saveContent() {
  saving.value = true
  saveError.value = ''
  saveSuccess.value = false
  try {
    const { data } = await skillsApi.update(selectedSkill.value.id, { content: editableContent.value })
    const idx = skills.value.findIndex(s => s.id === selectedSkill.value.id)
    if (idx !== -1) skills.value[idx] = data.skill
    selectedSkill.value = data.skill
    saveSuccess.value = true
    setTimeout(() => { saveSuccess.value = false }, 2000)
  } catch (e) {
    saveError.value = 'Save failed. Please try again.'
  } finally {
    saving.value = false
  }
}

async function switchToVersions() {
  activeTab.value = 'versions'
  if (versions.value.length > 0) return
  loadingVersions.value = true
  try {
    const { data } = await skillsApi.getVersions(selectedSkill.value.id)
    versions.value = data.versions
  } finally {
    loadingVersions.value = false
  }
}

function selectVersion(v) {
  selectedVersion.value = v
  revertError.value = ''
}

async function revertToVersion(v) {
  reverting.value = true
  revertError.value = ''
  try {
    const { data } = await skillsApi.revertVersion(selectedSkill.value.id, v.id)
    const idx = skills.value.findIndex(s => s.id === selectedSkill.value.id)
    if (idx !== -1) skills.value[idx] = data.skill
    selectedSkill.value = data.skill
    editableContent.value = data.skill.content || ''
    activeTab.value = 'content'
  } catch (e) {
    revertError.value = 'Revert failed. Please try again.'
  } finally {
    reverting.value = false
  }
}

function formatDate(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  return d.toLocaleString()
}
</script>

<style scoped>
.skills-view { padding: 24px; height: 100%; display: flex; flex-direction: column; }

.header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px; }
h2 { font-size: 20px; font-weight: 600; color: #fff; }

.skills-layout {
  display: grid;
  grid-template-columns: 300px 1fr;
  gap: 16px;
  flex: 1;
  min-height: 0;
}

/* Left panel */
.skills-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  overflow-y: auto;
}

.skill-card {
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 10px;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  cursor: pointer;
  transition: border-color 0.15s;
}

.skill-card:hover { border-color: #3a3a3a; }
.skill-card.selected { border-color: #4f46e5; background: #1a1a2e; }

.skill-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 8px;
}

.skill-name { font-size: 14px; font-weight: 600; color: #e8e8e8; }

.skill-badges { display: flex; gap: 4px; flex-wrap: wrap; }

.badge {
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 4px;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.badge.locked { background: #3a2a1a; color: #f59e0b; }
.badge.inactive { background: #2a1a1a; color: #f87171; }
.badge.namespace { background: #1a1a3a; color: #818cf8; }

.skill-meta { font-size: 12px; color: #555; display: flex; gap: 6px; }

.skill-actions { margin-top: 4px; }

/* Right panel */
.skill-editor {
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 10px;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow-y: auto;
}

.editor-empty {
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #555;
  font-size: 14px;
}

.editor-header { display: flex; flex-direction: column; gap: 4px; }

.editor-title { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }

.editor-skill-name { font-size: 18px; font-weight: 600; color: #e8e8e8; }

.editor-badges { display: flex; gap: 4px; }

.editor-meta { font-size: 12px; color: #555; }

/* Tabs */
.editor-tabs { display: flex; gap: 4px; border-bottom: 1px solid #2a2a2a; padding-bottom: 0; }

.tab-btn {
  background: transparent;
  border: none;
  border-bottom: 2px solid transparent;
  color: #666;
  font-size: 13px;
  padding: 6px 14px;
  cursor: pointer;
  margin-bottom: -1px;
  transition: color 0.15s, border-color 0.15s;
}

.tab-btn.active { color: #e8e8e8; border-bottom-color: #4f46e5; }
.tab-btn:hover:not(.active) { color: #aaa; }

/* Tab panes */
.tab-pane { display: flex; flex-direction: column; gap: 12px; flex: 1; }

.content-textarea {
  width: 100%;
  background: #0d0d0d;
  border: 1px solid #2a2a2a;
  border-radius: 6px;
  color: #d4d4d4;
  font-family: 'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace;
  font-size: 13px;
  line-height: 1.6;
  padding: 12px;
  resize: vertical;
  outline: none;
  box-sizing: border-box;
}

.content-textarea:focus { border-color: #4f46e5; }
.content-textarea.readonly { opacity: 0.8; cursor: default; }

.editor-actions { display: flex; align-items: center; gap: 12px; }

.btn-save {
  background: #4f46e5;
  color: #fff;
  border: none;
  border-radius: 6px;
  padding: 7px 18px;
  font-size: 13px;
  cursor: pointer;
}

.save-error { font-size: 12px; color: #f87171; }
.save-success { font-size: 12px; color: #86efac; }

/* Versions */
.versions-layout { display: grid; grid-template-columns: 200px 1fr; gap: 12px; }

.versions-list { display: flex; flex-direction: column; gap: 6px; overflow-y: auto; }

.version-item {
  background: #0d0d0d;
  border: 1px solid #2a2a2a;
  border-radius: 6px;
  padding: 10px 12px;
  cursor: pointer;
  transition: border-color 0.15s;
}

.version-item:hover { border-color: #3a3a3a; }
.version-item.selected { border-color: #4f46e5; background: #1a1a2e; }

.version-number { font-size: 13px; font-weight: 600; color: #e8e8e8; }

.version-meta { font-size: 11px; color: #555; display: flex; flex-direction: column; gap: 2px; margin-top: 4px; }

.version-preview { display: flex; flex-direction: column; gap: 10px; }

.loading { color: #555; font-size: 14px; padding: 20px; text-align: center; }
.empty { color: #555; font-size: 14px; padding: 20px; text-align: center; }
</style>
