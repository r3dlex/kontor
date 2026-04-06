import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

const { mockGet, mockPatch } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPatch: vi.fn()
}))

vi.mock('@/api', () => ({
  default: {
    defaults: { headers: { common: {} } },
    get: mockGet,
    patch: mockPatch
  }
}))

vi.mock('@/router', () => ({
  default: { push: vi.fn() }
}))

import { useTaskStore } from '@/stores/tasks'

describe('tasks store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('fetchTasks', () => {
    it('calls GET /tasks with no params when status is null', async () => {
      mockGet.mockResolvedValueOnce({ data: { tasks: [] } })
      const store = useTaskStore()
      await store.fetchTasks()
      expect(mockGet).toHaveBeenCalledWith('/tasks', { params: {} })
    })

    it('calls GET /tasks with status param when status is provided', async () => {
      mockGet.mockResolvedValueOnce({ data: { tasks: [] } })
      const store = useTaskStore()
      await store.fetchTasks('confirmed')
      expect(mockGet).toHaveBeenCalledWith('/tasks', { params: { status: 'confirmed' } })
    })

    it('populates tasks from the response', async () => {
      const fakeTasks = [
        { id: 1, title: 'Task A', importance: 0.9 },
        { id: 2, title: 'Task B', importance: 0.5 }
      ]
      mockGet.mockResolvedValueOnce({ data: { tasks: fakeTasks } })
      const store = useTaskStore()
      await store.fetchTasks()
      expect(store.tasks).toEqual(fakeTasks)
    })

    it('sets loading to true while fetching and false after completion', async () => {
      let resolveFetch
      mockGet.mockReturnValueOnce(
        new Promise((resolve) => { resolveFetch = resolve })
      )
      const store = useTaskStore()
      const fetchPromise = store.fetchTasks()
      expect(store.loading).toBe(true)
      resolveFetch({ data: { tasks: [] } })
      await fetchPromise
      expect(store.loading).toBe(false)
    })

    it('sets loading to false even when fetch throws', async () => {
      mockGet.mockRejectedValueOnce(new Error('Network error'))
      const store = useTaskStore()
      await expect(store.fetchTasks()).rejects.toThrow('Network error')
      expect(store.loading).toBe(false)
    })
  })

  describe('updateTask', () => {
    it('calls PATCH /tasks/:id with task attrs', async () => {
      const updatedTask = { id: 5, title: 'Updated', status: 'confirmed' }
      mockPatch.mockResolvedValueOnce({ data: { task: updatedTask } })
      const store = useTaskStore()
      store.tasks = [{ id: 5, title: 'Original', status: 'created' }]
      await store.updateTask(5, { status: 'confirmed' })
      expect(mockPatch).toHaveBeenCalledWith('/tasks/5', { task: { status: 'confirmed' } })
    })

    it('updates the task in the store tasks array', async () => {
      const updatedTask = { id: 5, title: 'Updated', status: 'confirmed' }
      mockPatch.mockResolvedValueOnce({ data: { task: updatedTask } })
      const store = useTaskStore()
      store.tasks = [{ id: 5, title: 'Original', status: 'created' }]
      await store.updateTask(5, { status: 'confirmed' })
      expect(store.tasks[0]).toEqual(updatedTask)
    })

    it('returns the updated task from the API', async () => {
      const updatedTask = { id: 7, status: 'done' }
      mockPatch.mockResolvedValueOnce({ data: { task: updatedTask } })
      const store = useTaskStore()
      store.tasks = [{ id: 7, status: 'confirmed' }]
      const result = await store.updateTask(7, { status: 'done' })
      expect(result).toEqual(updatedTask)
    })

    it('does not crash when task id is not found in the store', async () => {
      const updatedTask = { id: 99, status: 'done' }
      mockPatch.mockResolvedValueOnce({ data: { task: updatedTask } })
      const store = useTaskStore()
      store.tasks = [{ id: 1, status: 'created' }]
      await expect(store.updateTask(99, { status: 'done' })).resolves.toEqual(updatedTask)
      // Original task should be unchanged
      expect(store.tasks[0].id).toBe(1)
    })
  })

  describe('confirmTask', () => {
    it('calls updateTask with status confirmed', async () => {
      const updatedTask = { id: 3, status: 'confirmed' }
      mockPatch.mockResolvedValueOnce({ data: { task: updatedTask } })
      const store = useTaskStore()
      store.tasks = [{ id: 3, status: 'created' }]
      await store.confirmTask(3)
      expect(mockPatch).toHaveBeenCalledWith('/tasks/3', { task: { status: 'confirmed' } })
    })
  })

  describe('dismissTask', () => {
    it('calls updateTask with status dismissed', async () => {
      const updatedTask = { id: 4, status: 'dismissed' }
      mockPatch.mockResolvedValueOnce({ data: { task: updatedTask } })
      const store = useTaskStore()
      store.tasks = [{ id: 4, status: 'created' }]
      await store.dismissTask(4)
      expect(mockPatch).toHaveBeenCalledWith('/tasks/4', { task: { status: 'dismissed' } })
    })
  })

  describe('markDone', () => {
    it('calls updateTask with status done', async () => {
      const updatedTask = { id: 6, status: 'done' }
      mockPatch.mockResolvedValueOnce({ data: { task: updatedTask } })
      const store = useTaskStore()
      store.tasks = [{ id: 6, status: 'confirmed' }]
      await store.markDone(6)
      expect(mockPatch).toHaveBeenCalledWith('/tasks/6', { task: { status: 'done' } })
    })
  })

  describe('handleRealtimeUpdate', () => {
    it('updates an existing task in place when id matches', () => {
      const store = useTaskStore()
      store.tasks = [
        { id: 1, title: 'Old title', importance: 0.5 },
        { id: 2, title: 'Another', importance: 0.3 }
      ]
      store.handleRealtimeUpdate({ id: 1, title: 'New title', importance: 0.5 })
      expect(store.tasks[0].title).toBe('New title')
      expect(store.tasks).toHaveLength(2)
    })

    it('inserts a new task at the front when id is not found', () => {
      const store = useTaskStore()
      store.tasks = [{ id: 1, title: 'Existing', importance: 0.5 }]
      store.handleRealtimeUpdate({ id: 99, title: 'New task', importance: 0.4 })
      expect(store.tasks).toHaveLength(2)
      expect(store.tasks.find(t => t.id === 99)).toBeDefined()
    })

    it('sorts tasks by importance descending after inserting a new task', () => {
      const store = useTaskStore()
      store.tasks = [
        { id: 1, importance: 0.3 },
        { id: 2, importance: 0.6 }
      ]
      store.handleRealtimeUpdate({ id: 3, importance: 0.9 })
      expect(store.tasks[0].importance).toBe(0.9)
      expect(store.tasks[1].importance).toBe(0.6)
      expect(store.tasks[2].importance).toBe(0.3)
    })

    it('does not resort when updating an existing task', () => {
      const store = useTaskStore()
      store.tasks = [
        { id: 1, importance: 0.9 },
        { id: 2, importance: 0.1 }
      ]
      store.handleRealtimeUpdate({ id: 1, importance: 0.2 })
      // Position stays at index 0 (no re-sort for updates)
      expect(store.tasks[0].id).toBe(1)
      expect(store.tasks[0].importance).toBe(0.2)
    })
  })
})
