<template>
  <div class="task-list">
    <div class="header">
      <h2>Tasks</h2>
      <div class="filters">
        <button
          v-for="s in statuses"
          :key="s.value"
          :class="['filter-btn', { active: activeStatus === s.value }]"
          @click="setStatus(s.value)"
        >{{ s.label }}</button>
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
          <button
            v-if="task.status === 'created'"
            @click="taskStore.confirmTask(task.id)"
            class="btn-confirm"
          >Confirm</button>
          <button
            v-if="['confirmed', 'in_progress'].includes(task.status)"
            @click="taskStore.markDone(task.id)"
            class="btn-done"
          >Done</button>
          <button
            v-if="!['done', 'dismissed'].includes(task.status)"
            @click="taskStore.dismissTask(task.id)"
            class="btn-dismiss"
          >Dismiss</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useTaskStore } from '@/stores/tasks'
import { useChatStore } from '@/stores/chat'

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

.filter-btn {
  padding: 6px 14px;
  border-radius: 20px;
  border: 1px solid #333;
  background: transparent;
  color: #888;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.15s;
}

.filter-btn.active, .filter-btn:hover {
  background: #1f1f1f;
  color: #fff;
  border-color: #444;
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

.task-actions button {
  padding: 6px 12px;
  border-radius: 6px;
  border: 1px solid;
  font-size: 12px;
  cursor: pointer;
  transition: opacity 0.15s;
}

.btn-confirm { background: #1a3a5c; color: #7dd3fc; border-color: #2d5a8c; }
.btn-done { background: #1a3a1a; color: #86efac; border-color: #2d5c2d; }
.btn-dismiss { background: transparent; color: #555; border-color: #333; }

.loading, .empty { color: #555; font-size: 14px; padding: 40px; text-align: center; }
</style>
