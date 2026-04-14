<template>
  <div class="task-list">
    <div class="header">
      <h2>Tasks</h2>
      <div class="filters">
        <Button
          v-for="s in statuses"
          :key="s.value"
          :label="s.label"
          :class="['filter-btn', { 'p-button-outlined': activeStatus !== s.value, 'p-button-text': activeStatus === s.value, 'active': activeStatus === s.value }]"
          :severity="activeStatus === s.value ? 'primary' : 'secondary'"
          size="small"
          @click="setStatus(s.value)"
        />
      </div>
    </div>

    <div v-if="taskStore.loading" class="loading">Loading...</div>

    <div v-else-if="taskStore.tasks.length === 0" class="empty">
      No tasks found.
    </div>

    <div v-else class="tasks">
      <div
        v-for="task in taskStore.tasks"
        :key="task.id"
        class="task-card"
        :class="task.status"
      >
        <div class="task-importance" :style="{ opacity: task.importance }">
          <span class="importance-bar" :style="{ height: (task.importance * 40) + 'px' }" />
        </div>

        <div class="task-body">
          <div class="task-type-badge">{{ task.task_type }}</div>
          <h3>{{ task.title }}</h3>
          <p v-if="task.description">{{ task.description }}</p>
          <div class="task-meta">
            <span class="confidence">{{ Math.round(task.confidence * 100) }}% confidence</span>
            <span v-if="task.scheduled_action_at" class="deadline">
              Due {{ formatDate(task.scheduled_action_at) }}
            </span>
          </div>
        </div>

        <div class="task-actions">
          <Button
            v-if="task.status === 'created'"
            label="Confirm"
            size="small"
            severity="info"
            @click="taskStore.confirmTask(task.id)"
            class="btn-confirm"
          />
          <Button
            v-if="['confirmed', 'in_progress'].includes(task.status)"
            label="Done"
            size="small"
            severity="success"
            @click="taskStore.markDone(task.id)"
            class="btn-done"
          />
          <Button
            v-if="!['done', 'dismissed'].includes(task.status)"
            label="Dismiss"
            size="small"
            severity="secondary"
            text
            @click="taskStore.dismissTask(task.id)"
            class="btn-dismiss"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useTaskStore } from '@/stores/tasks'
import { useChatStore } from '@/stores/chat'
import Button from 'primevue/button'

const taskStore = useTaskStore()
const chat = useChatStore()
const activeStatus = ref(null)

const statuses = [
  { label: 'All', value: null },
  { label: 'Confirmed', value: 'confirmed' },
  { label: 'Review', value: 'created' },
  { label: 'Done', value: 'done' }
]

onMounted(() => {
  taskStore.fetchTasks()
  chat.setViewContext({
    view: 'task_list',
    available_actions: ['create_task', 'dismiss_task', 'confirm_task']
  })
})

function setStatus(status) {
  activeStatus.value = status
  taskStore.fetchTasks(status)
}

function formatDate(dt) {
  return new Date(dt).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}
</script>

<style scoped>
.task-list { padding: 24px; }

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

h2 { font-size: 20px; font-weight: 600; color: #fff; }

.filters { display: flex; gap: 6px; }

.task-list :deep(.filter-btn) {
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 13px;
}

.tasks { display: flex; flex-direction: column; gap: 8px; }

.task-card {
  display: flex;
  gap: 12px;
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 10px;
  padding: 16px;
  align-items: flex-start;
  transition: border-color 0.15s;
}

.task-card:hover { border-color: #3a3a3a; }
.task-card.confirmed { border-left: 3px solid #3b82f6; }
.task-card.done { opacity: 0.5; }

.task-importance {
  width: 4px;
  display: flex;
  align-items: flex-end;
  min-height: 40px;
}

.importance-bar {
  width: 4px;
  background: #3b82f6;
  border-radius: 2px;
  min-height: 4px;
}

.task-body { flex: 1; }

.task-type-badge {
  display: inline-block;
  font-size: 11px;
  color: #666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 4px;
}

h3 { font-size: 14px; font-weight: 500; color: #e8e8e8; margin-bottom: 4px; }

p { font-size: 13px; color: #777; margin-bottom: 8px; line-height: 1.4; }

.task-meta { display: flex; gap: 12px; }

.confidence, .deadline { font-size: 11px; color: #555; }
.deadline { color: #e87c3e; }

.task-actions { display: flex; gap: 6px; flex-shrink: 0; }

.loading, .empty { color: #555; font-size: 14px; padding: 40px; text-align: center; }
</style>
