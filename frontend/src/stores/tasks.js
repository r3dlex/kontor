import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api'

export const useTaskStore = defineStore('tasks', () => {
  const tasks = ref([])
  const loading = ref(false)

  async function fetchTasks(status = null) {
    loading.value = true
    try {
      const params = status ? { status } : {}
      const { data } = await api.get('/tasks', { params })
      tasks.value = data.tasks
    } finally {
      loading.value = false
    }
  }

  async function updateTask(id, attrs) {
    const { data } = await api.patch(`/tasks/${id}`, { task: attrs })
    const idx = tasks.value.findIndex(t => t.id === id)
    if (idx !== -1) tasks.value[idx] = data.task
    return data.task
  }

  async function confirmTask(id) {
    return updateTask(id, { status: 'confirmed' })
  }

  async function dismissTask(id) {
    return updateTask(id, { status: 'dismissed' })
  }

  async function markDone(id) {
    return updateTask(id, { status: 'done' })
  }

  function handleRealtimeUpdate(task) {
    const idx = tasks.value.findIndex(t => t.id === task.id)
    if (idx !== -1) {
      tasks.value[idx] = task
    } else {
      tasks.value.unshift(task)
      tasks.value.sort((a, b) => b.importance - a.importance)
    }
  }

  return { tasks, loading, fetchTasks, updateTask, confirmTask, dismissTask, markDone, handleRealtimeUpdate }
})
